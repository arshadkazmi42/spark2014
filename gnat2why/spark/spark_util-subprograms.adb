------------------------------------------------------------------------------
--                                                                          --
--                            GNAT2WHY COMPONENTS                           --
--                                                                          --
--                  S P A R K _ U T I L - S U B P R O G R A M S             --
--                                                                          --
--                                 B o d y                                  --
--                                                                          --
--                        Copyright (C) 2016-2016, AdaCore                  --
--                                                                          --
-- gnat2why is  free  software;  you can redistribute  it and/or  modify it --
-- under terms of the  GNU General Public License as published  by the Free --
-- Software  Foundation;  either version 3,  or (at your option)  any later --
-- version.  gnat2why is distributed  in the hope that  it will be  useful, --
-- but WITHOUT ANY WARRANTY; without even the implied warranty of  MERCHAN- --
-- TABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public --
-- License for  more details.  You should have  received  a copy of the GNU --
-- General  Public License  distributed with  gnat2why;  see file COPYING3. --
-- If not,  go to  http://www.gnu.org/licenses  for a complete  copy of the --
-- license.                                                                 --
--                                                                          --
-- gnat2why is maintained by AdaCore (http://www.adacore.com)               --
--                                                                          --
------------------------------------------------------------------------------

with Ada.Strings.Equal_Case_Insensitive;
with Ada.Strings.Unbounded;              use Ada.Strings.Unbounded;
with Ada.Strings;                        use Ada.Strings;
with Assumption_Types;                   use Assumption_Types;
with Flow_Types;                         use Flow_Types;
with Flow_Utility;                       use Flow_Utility;
with Gnat2Why_Args;
with Gnat2Why.Assumptions;               use Gnat2Why.Assumptions;
with GNATCOLL.Utils;                     use GNATCOLL.Utils;
with Nlists;                             use Nlists;
with Sem_Aux;                            use Sem_Aux;
with Sem_Ch12;                           use Sem_Ch12;
with Sem_Disp;                           use Sem_Disp;
with Sem_Util;                           use Sem_Util;
with SPARK_Util.Types;                   use SPARK_Util.Types;
with Stand;                              use Stand;
with VC_Kinds;                           use VC_Kinds;

package body SPARK_Util.Subprograms is

   ------------------------
   -- Analysis_Requested --
   ------------------------

   function Analysis_Requested
     (E            : Entity_Id;
      With_Inlined : Boolean) return Boolean is
   begin
      return
        --  Either the analysis is requested for the complete unit, or if it is
        --  requested for a specific subprogram/task, check whether it is E.

        Is_In_Analyzed_Files (E) and then
        (
         --  Always analyze the subprogram if analysis was specifically
         --  requested for it.
         Is_Requested_Subprogram_Or_Task (E)

         --  Anlways analyze if With_Inlined is True. Also, always analyze
         --  unreferenced subprograms, as they are likely to correspond to
         --  an intermediate stage of development. Otherwise, only analyze
         --  subprograms that are not inlined.

         or else (Gnat2Why_Args.Limit_Subp = Null_Unbounded_String
                    and then
                    (With_Inlined
                       or else not Referenced (E)
                       or else not Is_Local_Subprogram_Always_Inlined (E))));

   end Analysis_Requested;

   -------------------------------
   -- Containing_Protected_Type --
   -------------------------------

   function Containing_Protected_Type (E : Entity_Id) return Entity_Id is
      Scop : Node_Id := Scope (E);
   begin
      while Present (Scop) loop
         if Ekind (Scop) in Protected_Kind then
            return Scop;
         end if;
         Scop := Scope (Scop);
      end loop;

      --  should not reach this - we should be in the scope of a protected type

      raise Program_Error;

   end Containing_Protected_Type;

   ----------------
   -- Entry_Body --
   ----------------

   function Entry_Body (E : Entity_Id) return Node_Id
   is
      Ptr : constant Node_Id := Entry_Body_Entity (E);
   begin
      return (if Present (Ptr)
              then Parent (Ptr)
              else Empty);
   end Entry_Body;

   -----------------------
   -- Entry_Body_Entity --
   -----------------------

   function Entry_Body_Entity (E : Entity_Id) return Entity_Id
   is
      Ptr : constant Node_Id := Parent (E);
   begin
      pragma Assert (Nkind (Ptr) = N_Entry_Declaration);
      return Corresponding_Body (Ptr);
   end Entry_Body_Entity;

   --------------------
   -- Find_Contracts --
   --------------------

   function Find_Contracts
     (E         : Entity_Id;
      Name      : Name_Id;
      Classwide : Boolean := False;
      Inherited : Boolean := False) return Node_Lists.List
   is
      function Filter_Classwide_Contracts
        (Pragmas : Node_Lists.List;
         From    : Entity_Id) return Node_Lists.List;
      --  Return the contracts from Contracts that are inherited from From

      --------------------------------
      -- Filter_Classwide_Contracts --
      --------------------------------

      function Filter_Classwide_Contracts
        (Pragmas : Node_Lists.List;
         From    : Entity_Id) return Node_Lists.List
      is
         Result : Node_Lists.List;
      begin
         for Prag of Pragmas loop
            if Entity (Corresponding_Aspect (Prag)) = From then
               Result.Append (Prag);
            end if;
         end loop;
         return Result;
      end Filter_Classwide_Contracts;

      --  Local variables

      Contr   : Node_Id := Contract (E);
      Prag    : Node_Id;
      Pragmas : Node_Lists.List := Node_Lists.Empty_List;

      Class_Expected : constant Boolean := Classwide or Inherited;
      --  True iff the Class flag should be set on selected pragmas

   --  Start of processing for Find_Contracts

   begin
      case Name is
         when Name_Precondition      |
              Name_Postcondition     |
              Name_Refined_Post      |
              Name_Contract_Cases    |
              Name_Initial_Condition =>

            if Name = Name_Refined_Post then
               if Ekind (E) in Subprogram_Kind
                 and then Present (Subprogram_Body (E))
               then
                  Contr := Contract (Defining_Entity (Specification
                                                    (Subprogram_Body (E))));
               elsif Ekind (E) = E_Entry
                 and then Present (Entry_Body (E))
               then
                  Contr := Contract (Entry_Body_Entity (E));
               else
                  Contr := Empty;
               end if;
            end if;

            if Present (Contr) then
               Prag := (case Name is
                        when Name_Precondition  |
                             Name_Postcondition |
                             Name_Refined_Post  => Pre_Post_Conditions (Contr),
                        when Name_Initial_Condition => Classifications (Contr),
                        when others => Contract_Test_Cases (Contr));

               while Present (Prag) loop
                  if Chars (Pragma_Identifier (Prag)) = Name
                    and then Class_Present (Prag) = Class_Expected
                  then
                     Pragmas.Append (Prag);
                  end if;

                  Prag := Next_Pragma (Prag);
               end loop;
            end if;

         when Name_Global | Name_Depends =>
            raise Why.Not_Implemented;

         when others =>
            raise Program_Error;
      end case;

      --  If Inherited is True, look for an inherited contract, starting from
      --  the closest overridden subprogram.

      --  ??? Does not work for multiple inheritance through interfaces

      if Classwide then
         Pragmas := Filter_Classwide_Contracts (Pragmas, E);

      elsif Inherited then
         declare
            Inherit_Subp : constant Subprogram_List :=
              Inherited_Subprograms (E);
            Inherit_Pragmas : Node_Lists.List;
         begin
            for J in Inherit_Subp'Range loop
               Inherit_Pragmas :=
                 Filter_Classwide_Contracts (Pragmas, Inherit_Subp (J));
               exit when not Inherit_Pragmas.Is_Empty;
            end loop;
            Pragmas := Inherit_Pragmas;
         end;
      end if;

      --  Extract the Boolean expressions inside the pragmas, and return the
      --  list of these expressions.

      declare
         Contracts : Node_Lists.List;
      begin
         for P of Pragmas loop
            Contracts.Append
              (Expression (First (Pragma_Argument_Associations (P))));
         end loop;

         return Contracts;
      end;
   end Find_Contracts;

   ------------------------
   -- Get_Execution_Kind --
   ------------------------

   function Get_Execution_Kind
     (E        : Entity_Id;
      After_GG : Boolean := True) return Execution_Kind_T
   is
      function Has_No_Output return Boolean;
      --  Return True if procedure E has no output (parameter or global).
      --  Otherwise, or if we don't know for sure, return False. If After_GG
      --  is False, then we will not query generated globals.

      -------------------
      -- Has_No_Output --
      -------------------

      function Has_No_Output return Boolean is
         Params : constant List_Id :=
           Parameter_Specifications (Subprogram_Specification (E));
         Param  : Node_Id;

         Read_Ids    : Flow_Types.Flow_Id_Sets.Set;
         Write_Ids   : Flow_Types.Flow_Id_Sets.Set;
         Write_Names : Name_Sets.Set;

      begin
         --  Consider output parameters

         Param := First (Params);
         while Present (Param) loop
            case Formal_Kind'(Ekind (Defining_Identifier (Param))) is
               when E_Out_Parameter | E_In_Out_Parameter =>
                  return False;
               when E_In_Parameter =>
                  null;
            end case;
            Next (Param);
         end loop;

         --  Consider output globals if they can be relied upon, either because
         --  this is after the generation of globals, or because the user has
         --  supplied them.

         if After_GG or else Has_User_Supplied_Globals (E) then
            Flow_Utility.Get_Proof_Globals (Subprogram => E,
                                            Classwide  => True,
                                            Reads      => Read_Ids,
                                            Writes     => Write_Ids);
            Write_Names := Flow_Types.To_Name_Set (Write_Ids);

            return Write_Names.Is_Empty;

         --  Otherwise we don't know, return False to be on the safe side

         else
            return False;
         end if;
      end Has_No_Output;

   --  Start of processing for Get_Execution_Kind

   begin
      if Has_No_Output then
         return Abnormal_Termination;
      else
         return Infinite_Loop;
      end if;
   end Get_Execution_Kind;

   -----------------------------------
   -- Get_Expr_From_Check_Only_Proc --
   -----------------------------------

   function Get_Expr_From_Check_Only_Proc (E : Entity_Id) return Node_Id is
      Body_N : constant Node_Id := Subprogram_Body (E);
      Stmt   : Node_Id;
      Arg    : Node_Id;

   begin
      --  If there is no associated body, return Empty.

      if No (Body_N) then
         return Empty;
      end if;

      Stmt := First (Statements (Handled_Statement_Sequence (Body_N)));

      while Present (Stmt) loop

         --  Return the second argument of the first pragma Check in the
         --  statement list if any.

         if Nkind (Stmt) = N_Pragma
           and then Get_Pragma_Id (Pragma_Name (Stmt)) = Pragma_Check
         then
            pragma Assert (Present (Pragma_Argument_Associations (Stmt)));
            Arg := First (Pragma_Argument_Associations (Stmt));
            pragma Assert (Present (Arg));
            Arg := Next (Arg);
            pragma Assert (Present (Arg));
            return (Get_Pragma_Arg (Arg));
         end if;

         Next (Stmt);
      end loop;

      --  Otherwise return Empty

      return Empty;
   end Get_Expr_From_Check_Only_Proc;

   ------------------------------------
   -- Get_Expr_From_Return_Only_Func --
   ------------------------------------

   function Get_Expr_From_Return_Only_Func (E : Entity_Id) return Node_Id is
      Body_N : constant Node_Id := Subprogram_Body (E);
      Stmt   : Node_Id;

   begin
      --  If there is no associated body, return Empty.

      if No (Body_N) then
         return Empty;
      end if;

      Stmt := First (Statements (Handled_Statement_Sequence (Body_N)));

      while Present (Stmt) loop

         --  Return the argument of the first return statement in the statement
         --  list if any.

         if Nkind (Stmt) = N_Simple_Return_Statement then
            return Expression (Stmt);
         end if;

         Next (Stmt);
      end loop;

      --  Otherwise return Empty

      return Empty;
   end Get_Expr_From_Return_Only_Func;

   -----------------------------
   -- Get_Expression_Function --
   -----------------------------

   function Get_Expression_Function (E : Entity_Id) return Node_Id is
      Decl_N : constant Node_Id := Parent (Subprogram_Specification (E));

      Original_Decl_N : constant Node_Id := Original_Node (Decl_N);

      --  Get the original node either from the declaration for E, or from the
      --  subprogram body for E, which may be different if E is attached to a
      --  subprogram declaration.

      Orig_N : constant Node_Id :=
        (if Present (Original_Decl_N)
           and then Original_Decl_N /= Decl_N
         then Original_Decl_N
         else Original_Node (Subprogram_Body (E)));

   begin
      if Nkind (Orig_N) = N_Expression_Function then
         return Orig_N;
      else
         return Empty;
      end if;
   end Get_Expression_Function;

   ----------------------------------------
   -- Get_Priority_Or_Interrupt_Priority --
   ----------------------------------------

   function Get_Priority_Or_Interrupt_Priority (E : Entity_Id) return Node_Id
   is
      Pragma_Priority_Node : constant Node_Id :=
        Get_Pragma (E, Pragma_Priority);
   begin
      if Present (Pragma_Priority_Node) then
         --  Expression is mandatory for pragma Priority

         return Expression
           (First (Pragma_Argument_Associations (Pragma_Priority_Node)));

      else
         declare
            Interrupt_Priority_Pragma_Node : constant Node_Id :=
              Get_Pragma (E, Pragma_Interrupt_Priority);
         begin
            if Present (Interrupt_Priority_Pragma_Node) then
               declare
                  Arg : constant Node_Id :=
                    First
                      (Pragma_Argument_Associations
                         (Interrupt_Priority_Pragma_Node));
               begin
                  --  Expression is optional for pragma Interrupt_Priority
                  return (if Present (Arg)
                          then Expression (Arg)
                          --  Here priority defaults to Interrupt_Priority'Last
                          else Empty);
               end;
            else
               --  None of pragma Priority or Interrupt_Priority is present

               return Empty;
            end if;
         end;
      end if;

   end Get_Priority_Or_Interrupt_Priority;

   -------------------
   -- Has_Contracts --
   -------------------

   function Has_Contracts
     (E         : Entity_Id;
      Name      : Name_Id;
      Classwide : Boolean := False;
      Inherited : Boolean := False) return Boolean
   is
      Contracts : Node_Lists.List;

   begin
      if Classwide or Inherited then
         if Classwide then
            Contracts := Find_Contracts (E, Name, Classwide => True);
         end if;

         if Contracts.Is_Empty and then Inherited then
            Contracts := Find_Contracts (E, Name, Inherited => True);
         end if;

      else
         Contracts := Find_Contracts (E, Name);
      end if;

      return not Contracts.Is_Empty;
   end Has_Contracts;

   ----------------------------
   -- Has_Extensions_Visible --
   ----------------------------

   function Has_Extensions_Visible (E : Entity_Id) return Boolean is
     (Present (Get_Pragma (E, Pragma_Extensions_Visible)));

   -------------------------------
   -- Has_User_Supplied_Globals --
   -------------------------------

   function Has_User_Supplied_Globals (E : Entity_Id) return Boolean is
     (Present (Get_Pragma (E, Pragma_Global))
        or else Present (Get_Pragma (E, Pragma_Depends)));

   -------------------------------------
   -- Has_Only_Nonblocking_Statements --
   -------------------------------------

   function Has_Only_Nonblocking_Statements (N : Node_Id) return Boolean is

      Potentially_Blocking_Statement_Found : Boolean := False;
      --  Flag used as an output for the AST traversal procedure

      function Proc (N : Node_Id) return Traverse_Result;
      --  Process a node to check if it is a potentially blocking statement
      --  ??? respect SPARK_Mode => Off and do not look into bodies of nested
      --  entities

      procedure Traverse is new Traverse_Proc (Proc);
      --  Traverse a tree to check if it includes blocking statements

      function Is_Predefined_Potentially_Blocking
        (E : Entity_Id)
         return Boolean;
      --  Check if entity E is a predefined potentially blocking subprogram

      ----------------------------------------
      -- Is_Predefined_Potentially_Blocking --
      ----------------------------------------

      function Is_Predefined_Potentially_Blocking
        (E : Entity_Id)
         return Boolean
      is
         --  Detect:
         --    Ada.Task_Identification.Abort_Task
         --    Ada.Dispatching.Yield
         --    Ada.Synchronous_Task_Control.Suspend_Until_True
         --    Ada.Synchronous_Task_Control.EDF.
         --        Suspend_Until_True_And_Set_Deadline
         --    Ada.Synchronous_Barriers.Wait_For_Release
         --    System.RPC.*
         --
         --  and file-manipulating subprograms:
         --    Ada.Directories.*
         --    Ada.Text_IO.*
         --    Ada.Wide_Text_IO.*
         --    Ada.Wide_Wide_Text_IO.*
         --    Ada.Direct_IO.*
         --    Ada.Sequential_IO.*
         --    Ada.Streams.*
         --
         --  with notable exception of
         --    Ada.Storage_IO (input-output to memory buffer).

         --  It is more natural to detect these subprograms by first collecting
         --  the scope hierarchy and then analysing it starting from the
         --  outermost scope.
         --
         --  Note: to detect any of the predefined potentially blocking
         --  subprograms we only need up to 5 outermost scopes, like:
         --    (0) Standard.
         --    (1)  Ada.
         --    (2)   Text_IO.
         --    (3)    Editing.
         --    (4)     Decimal_Output
         --  and for System.RPC.* we need only the 3 outermost scopes, i.e.
         --    (0) Standard.
         --    (1)  System.
         --    (2)   RPC.
         --  Thus we avoid the use of much heavier Ada.Container.Vector/List,
         --  and use a circullar buffer instead.

         Max_Predefined_Potentially_Blocking_Nesting : constant := 5;
         --  Maximal nesting of predefined potentially blocking subprograms

         type Scope_Index is mod Max_Predefined_Potentially_Blocking_Nesting;
         --  Modular type for indexing the circullar buffer

         Scopes : array (Scope_Index) of Entity_Id;
         --  Circullar buffer with scopes of a call

         Scope_Id : Scope_Index := Scope_Index'Last;
         --  Indexing variable

         function Scope_Name (Nth : Scope_Index) return Name_Id with
           Pure_Function;
         --  Return name of the Nth scope for the analyzed entity.
         --  For 0 the result is always Standard,
         --  For 1 the result is Ada/Interfaces/System or user-defined,
         --  Etc.
         --
         --  Aspect Pure_Function is ment to improve performance when using
         --  this function as an array.

         ----------------
         -- Scope_Name --
         ----------------

         function Scope_Name (Nth : Scope_Index) return Name_Id is
           (Chars (Scopes (Scope_Id + Nth)));

      --  Start of processing for Is_Predefined_Potentially_Blocking

      begin
         --  Start from the called subprogram
         Scopes (Scope_Id) := E;

         --  Collect scopes up to the outermost one, i.e. Standard
         while Scopes (Scope_Id) /= Standard_Standard loop
            declare
               Parent_Scope : Entity_Id := Scope (Scopes (Scope_Id));
            begin
               --  If the parent scope is an instance of a generic package
               --  then analyze the generic and not its instance.
               if Ekind (Parent_Scope) = E_Package
                 and then Is_Generic_Instance (Parent_Scope)
               then
                  Parent_Scope :=
                    Entity
                      (Name (Get_Package_Instantiation_Node (Parent_Scope)));
               end if;

               Scope_Id := Scope_Id - 1;
               Scopes (Scope_Id) := Parent_Scope;
            end;
         end loop;
         --  Now we have something like:
         --  Scopes (Scope_Id)     -> Standard
         --  Scopes (Scope_Id + 1) -> Ada/Interfaces/System/...
         --  Scopes (Scope_Id + 2) -> Synchronous_Task_Control/...
         --  Scopes (Scope_Id + 3) -> EDF/Suspend_Until_True/...
         --  Scopes (Scope_Id + 4) -> Suspend_Until_True_And_Set_Deadline/...

         --  Dive into the scope hierarchy and look for names of predefined
         --  blocking subprograms.
         case Scope_Name (1) is
            when Name_Ada =>
               --  Further checks needed
               null;

            when Name_Interfaces =>
               --  All subprograms in package Interfaces are nonblocking
               return False;

            when Name_System =>
               --  Only subprograms in System.RPC are blocking
               return Scope_Name (2) = Name_Rpc;

            when others =>
               --  It is a user-defined subprogram and the call itself is
               --  nonblocking. If the target subprogram is potentially
               --  blocking, then it will be detected by call graph traversal.
               return False;
         end case;

         --  All subprograms in the child packages of Ada are blocking
         if Scope_Name (2) in Name_Directories   |
                              Name_Direct_IO     |
                              Name_Sequential_IO |
                              Name_Streams
         then
            --  Ada.Directories.Hierarchical_File_Names seems nonblocking. We
            --  conciously ignore it, since it is not yet implemented in GNAT
            --  and extremely unlikely to be needed in nonblocking contexts.
            return True;

         --  Child packages of Ada.[Wide_[Wide_]]Text_IO are identical
         elsif Scope_Name (2) in Name_Text_IO         |
                                 Name_Wide_Text_IO    |
                                 Name_Wide_Wide_Text_IO
         then
            --  Operations on bounded/unbounded strings either print or read
            --  them and thus are potentially blocking.
            if Scope_Name (3) in Name_Bounded_IO | Name_Unbounded_IO
            then
               return True;

            --  These generics have both blocking and nonblocking Put/Get
            elsif Scope_Name (3) in Name_Complex_IO | Text_IO_Package_Name
            then
               --  The name of the subproram (i.e. Put or Get) makes
               --  no difference (and it troublesome to know because of
               --  overriding). Blocking/Nonblocking status is determined
               --  by the name of the first formal parameter.
               --  * "File" means input/output to a specific file
               --  * "Item" means input/output to a default file
               --  * anything else means input/output to a string buffer
               return Chars (First_Formal (E)) in Name_File | Name_Item;

            --  These packages operate only on internal data structers and thus
            --  are nonblocking.
            elsif Scope_Name (3) in Name_C_Streams          |
                                    Name_Text_Streams       |
                                    Name_Reset_Standard_Files
            then
               return False;

            --  Ada.Text_IO.Editing is nonblocking, except for Decimal_IO
            elsif Scope_Name (3) = Name_Editing
            then
               if Scope_Name (4) = Name_Decimal_IO then
                  --  The only blocking subprograms are:
                  --    procedure Put (File : Ada.Text_IO.File_Type; ...)
                  --    procedure Put (Item : Num; ...)
                  --  and they are also detected by the name of the first
                  --  formal parameter.
                  return Ekind (E) = E_Procedure and then
                    Chars (First_Formal (E)) in Name_File | Name_Item;
               else
                  return False;
               end if;
            else
               --  Assume that all subprograms directly within Ada.Text_IO
               --  are potentially blocking. This is true for most of them,
               --  e.g. for Create/Open/Close/Delete, but in GNAT there few
               --  exceptions, e.g. Mode/Name/Form/Is_Open. However, they can
               --  be blocking in other compilers, so assume the worst case.
               return True;
            end if;

         elsif Scope_Name (2) = Name_Dispatching then
            return Scope_Name (3) = Name_Yield;

         elsif Scope_Name (2) = Name_Task_Identification then
            return Scope_Name (3) = Name_Abort_Task;

         elsif Scope_Name (2) = Name_Synchronous_Task_Control then

            if Scope_Name (3) = Name_Suspend_Until_True then
               return True;
            elsif Scope_Name (3) = Name_EDF then
               return Scope_Name (4) =
                 Name_Suspend_Until_True_And_Set_Deadline;
            else
               return False;
            end if;

         elsif Scope_Name (2) = Name_Synchronous_Barriers then
            return Scope_Name (3) = Name_Wait_For_Release;

         else
            --  All other predefined subprograms are nonblocking.
            return False;
         end if;

      end Is_Predefined_Potentially_Blocking;

      ----------
      -- Proc --
      ----------

      function Proc (N : Node_Id) return Traverse_Result is
      begin
         --  Detect a potentially blocking statement; RM 9.5.1 (8-16).
         --  The following check mirrors the callers of
         --  Check_Potentially_Blocking_Operation but immediately rejects
         --  all kinds of the select statement.
         case Nkind (N) is
            when N_Abort_Statement        |
                 N_Accept_Statement       |
                 N_Asynchronous_Select    |
                 N_Conditional_Entry_Call |
                 N_Delay_Statement        |
                 N_Selective_Accept       |
                 N_Timed_Entry_Call       =>

               Potentially_Blocking_Statement_Found := True;
               return Abandon;

            --  Front end rewrites external calls to protected procedures as
            --  entry calls. It is best to check the call convention.

            when N_Entry_Call_Statement =>

               if Convention (Entity (Selector_Name (Name (N)))) =
                 Convention_Entry
               then
                  Potentially_Blocking_Statement_Found := True;
                  return Abandon;
               else
                  return OK;
               end if;

            --  Predefined potentially blocking subprograms cannot be reliably
            --  detected in phase 2, where we only have entity names. Here
            --  we have full AST of their specifications and can precisely
            --  distinguish between blocking/nonblocking homonyms, e.g.
            --  Put/Get, by looking at the name of their first formal
            --  parameter. In phase 2 we only have names like "put__2"
            --  and "put__3".
            when N_Procedure_Call_Statement |
                 N_Function_Call =>

               if Is_Predefined_Potentially_Blocking (Get_Called_Entity (N))
               then
                  Potentially_Blocking_Statement_Found := True;
                  return Abandon;
               else
                  return OK;
               end if;

            when N_Object_Declaration =>
               --  ??? non-library-level task declarations should be already
               --  rejected by the Ravenscar profile restrictions.
               if Has_Task (Etype (Defining_Identifier (N))) then
                  Potentially_Blocking_Statement_Found := True;
                  return Abandon;
               else
                  return OK;
               end if;

            when others =>
               return OK;
         end case;
      end Proc;

   --  Start of processing for Has_Only_Nonblocking_Statements

   begin
      Traverse (N);
      return not Potentially_Blocking_Statement_Found;
   end Has_Only_Nonblocking_Statements;

   -----------------------------
   -- In_Private_Declarations --
   -----------------------------

   function In_Private_Declarations (Decl : Node_Id) return Boolean is
      Par : constant Node_Id := Parent (Decl);
   begin
      return
        Present (Par)
        and then Nkind (Par) = N_Package_Specification
        and then Is_List_Member (Decl)
        and then List_Containing (Decl) = Private_Declarations (Par);
   end In_Private_Declarations;

   -----------------------------
   -- In_Visible_Declarations --
   -----------------------------

   function In_Visible_Declarations (Decl : Node_Id) return Boolean is
      Par : constant Node_Id := Parent (Decl);
   begin
      return
        Present (Par)
        and then Nkind (Par) = N_Package_Specification
        and then Is_List_Member (Decl)
        and then List_Containing (Decl) = Visible_Declarations (Par);
   end In_Visible_Declarations;

   ----------------------------------------
   -- Is_Invisible_Dispatching_Operation --
   ----------------------------------------

   function Is_Invisible_Dispatching_Operation
     (E : Entity_Id) return Boolean
   is
      Param : Entity_Id;
      Etyp  : Entity_Id;

   begin
      if Has_Controlling_Result (E) then
         Etyp := Etype (E);

      else
         Param := First_Entity (E);
         while Present (Param)
           and then Is_Formal (Param)
           and then not Is_Controlling_Formal (Param)
         loop
            Next_Entity (Param);
         end loop;

         Etyp := Etype (Param);
      end if;

      return Is_Private_Type (Etyp)
        and then not Is_Tagged_Type (Etyp)
        and then Present (Subprogram_Spec (E))
        and then In_Visible_Declarations (Subprogram_Spec (E));
   end Is_Invisible_Dispatching_Operation;

   ----------------------------------------
   -- Is_Local_Subprogram_Always_Inlined --
   ----------------------------------------

   function Is_Local_Subprogram_Always_Inlined
     (E : Entity_Id) return Boolean
   is
      Spec : Node_Id;

      function Has_Renaming_As_Body (E : Entity_Id) return Boolean;
      --  Returns true iff subprogram E is completed by renaming-as-body

      --------------------------
      -- Has_Renaming_As_Body --
      --------------------------

      function Has_Renaming_As_Body (E : Entity_Id) return Boolean is
         B : constant Node_Id := Subprogram_Body (E);
      begin
         return Present (B)
           and then Present (Prev (B))
           and then Nkind (Prev (B)) = N_Subprogram_Renaming_Declaration
           and then Corresponding_Spec (Prev (B)) = E;
      end Has_Renaming_As_Body;

   --  Start of processing for Is_Local_Subprogram_Always_Inlined

   begin
      --  A subprogram always inlined should have Body_To_Inline set and
      --  flag Is_Inlined_Always set to True. However, subprograms with
      --  renaming-as-body satisfy these conditions and are not always inlined.

      --  Also, subprograms of protected objects are never inlined

      if not Is_Subprogram (E)
        or else not Is_Inlined_Always (E)
        or else Convention (E) = Convention_Protected
      then
         return False;
      end if;

      Spec := Subprogram_Spec (E);

      return Present (Spec)
        and then Present (Body_To_Inline (Spec))
        and then not Has_Renaming_As_Body (E);
   end Is_Local_Subprogram_Always_Inlined;

   -----------------------------
   -- Is_Protected_Subprogram --
   -----------------------------

   function Is_Protected_Subprogram (E : Entity_Id) return Boolean is
      Scop : Node_Id;
   begin
      case Ekind (E) is

         --  Entries are always protected subprograms
         when E_Entry =>
            return True;

         --  Detect subprograms declared in scope of a protected type
         when Subprogram_Kind =>

            Scop := Scope (E);
            while Present (Scop) loop
               if Ekind (Scop) in E_Protected_Type then
                  return True;
               end if;
               Scop := Scope (Scop);
            end loop;

            return False;

         when others =>
            return False;

      end case;
   end Is_Protected_Subprogram;

   -------------------------------------
   -- Is_Requested_Subprogram_Or_Task --
   -------------------------------------

   function Is_Requested_Subprogram_Or_Task (E : Entity_Id) return Boolean is
     (Ekind (E) in Subprogram_Kind | Task_Kind | E_Task_Body | Entry_Kind
        and then
      GP_Subp_Marker & To_String (Gnat2Why_Args.Limit_Subp) =
        SPARK_Util.Subprograms.Subp_Location (E));

   -------------------------------
   -- Is_Simple_Shift_Or_Rotate --
   -------------------------------

   function Is_Simple_Shift_Or_Rotate (E : Entity_Id) return Boolean is

      --  Define a convenient short hand for the test below
      function ECI (Left, Right : String) return Boolean
        renames Equal_Case_Insensitive;

   begin
      Get_Unqualified_Decoded_Name_String (Chars (E));

      declare
         Name : constant String := Name_Buffer (1 .. Name_Len);
      begin
         return  --  return True iff...

           --  it is an intrinsic
           Is_Intrinsic_Subprogram (E)

           --  modular type
           and then Is_Modular_Integer_Type (Etype (E))

           --  without functional contract
           and then not Has_Contracts (E, Name_Precondition)
           and then not Has_Contracts (E, Name_Postcondition)
           and then not Has_Contracts (E, Name_Contract_Cases)

           --  which corresponds to a shift or rotate
           and then
             (ECI (Name, Get_Name_String (Name_Shift_Right))
                or else
              ECI (Name, Get_Name_String (Name_Shift_Right_Arithmetic))
                or else
              ECI (Name, Get_Name_String (Name_Shift_Left))
                or else
              ECI (Name, Get_Name_String (Name_Rotate_Left))
                or else
              ECI (Name, Get_Name_String (Name_Rotate_Right)));
      end;
   end Is_Simple_Shift_Or_Rotate;

   -------------------
   -- Might_Be_Main --
   -------------------

   function Might_Be_Main (E : Entity_Id) return Boolean is
      Spec : Node_Id;
   begin
      --  This function mirrors tests in
      --    Lib.Write.Write_ALI.Output_Main_Program_Line
      --  which are more restrictive than those in
      --    Sem_Ch13.Analyze_Pragma.Check_In_Main_Program.

      --  Check if it is a library-level subprogram
      if Scope (E) /= Standard_Standard then
         return False;
      end if;

      Spec := Parent (E);

      pragma Assert (Nkind (Spec) in N_Function_Specification |
                                     N_Procedure_Specification);

      --  Check if it has no parameters
      if Parameter_Specifications (Spec) /= No_List then
         return False;
      end if;

      --  Check if it is a procedure or a function that returns an integer
      return (case Nkind (Spec) is
                 when N_Procedure_Specification =>
                    True,

                 when N_Function_Specification =>
                    Is_Integer_Type (Etype (E)),

                 when others =>
                    raise Program_Error
             );
   end Might_Be_Main;

   -------------------
   -- Subp_Location --
   -------------------

   --  Only consider the first location in the chain of locations for an
   --  instantiation or an inlining. This matches the location given by
   --  users inside a generic/inlined subprogram.

   function Subp_Location (E : Entity_Id) return String is
      S : constant Subp_Type := Entity_To_Subp (E);
      B : constant Base_Sloc := Subp_Sloc (S).First_Element;
   begin
      return GP_Subp_Marker & Base_Sloc_File (B) & ":" & Image (B.Line, 1);
   end Subp_Location;

   ---------------------------------
   -- Subprogram_Full_Source_Name --
   ---------------------------------

   function Subprogram_Full_Source_Name (E : Entity_Id) return String is
      Name : constant String := Source_Name (E);

   begin
      if Has_Fully_Qualified_Name (E)
        or else Scope (E) = Standard_Standard
      then
         return Name;
      else
         return Subprogram_Full_Source_Name (Unique_Entity (Scope (E))) &
           "." & Name;
      end if;
   end Subprogram_Full_Source_Name;

   -------------------------------------
   -- Subprogram_Is_Ignored_For_Proof --
   -------------------------------------

   --  Functions generated by the frontend for aspects Type_Invariant and
   --  Default_Initial_Condition should be ignored. This does not include
   --  the functions generated for Predicate aspects, as these functions are
   --  translated to check absence of RTE in the predicate in the most general
   --  context.

   function Subprogram_Is_Ignored_For_Proof (E : Entity_Id) return Boolean is
     (Ekind (E) = E_Procedure and then
        (Is_Invariant_Procedure (E)
           or else
         Is_Default_Init_Cond_Procedure (E)));

   --------------
   -- Get_Body --
   --------------

   function Get_Body (E : Entity_Id) return Node_Id is
   begin
      return (case Ekind (E) is
                 when Entry_Kind       => Entry_Body (E),
                 when E_Function |
                      E_Procedure      => Subprogram_Body (E),
                 when E_Protected_Type => Protected_Body (E),
                 when E_Task_Type      => Task_Body (E),
                 when others           => raise Program_Error);
   end Get_Body;

   ---------------------
   -- Get_Body_Entity --
   ---------------------

   function Get_Body_Entity (E : Entity_Id) return Entity_Id is
   begin
      return (case Ekind (E) is
                 when E_Entry         => Entry_Body_Entity (E),
                 when E_Task_Type     => Task_Body_Entity (E),
                 when Subprogram_Kind => Subprogram_Body_Entity (E),
                 when others          => raise Program_Error);
   end Get_Body_Entity;

end SPARK_Util.Subprograms;