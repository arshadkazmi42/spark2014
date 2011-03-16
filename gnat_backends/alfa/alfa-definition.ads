------------------------------------------------------------------------------
--                                                                          --
--                         GNAT BACK-END COMPONENTS                         --
--                                                                          --
--                       A L F A . D E F I N I T I O N                      --
--                                                                          --
--                                  S p e c                                 --
--                                                                          --
--             Copyright (C) 2011, Free Software Foundation, Inc.           --
--                                                                          --
-- GNAT is free software;  you can  redistribute it  and/or modify it under --
-- terms of the  GNU General Public License as published  by the Free Soft- --
-- ware  Foundation;  either version 3,  or (at your option) any later ver- --
-- sion.  GNAT is distributed in the hope that it will be useful, but WITH- --
-- OUT ANY WARRANTY;  without even the  implied warranty of MERCHANTABILITY --
-- or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License --
-- for  more details.  You should have  received  a copy of the GNU General --
-- Public License  distributed with GNAT; see file COPYING3.  If not, go to --
-- http://www.gnu.org/licenses for a complete copy of the license.          --
--                                                                          --
-- GNAT was originally developed  by the GNAT team at  New York University. --
-- Extensive contributions were provided by Ada Core Technologies Inc.      --
--                                                                          --
------------------------------------------------------------------------------

package ALFA.Definition is

   type Violation_Kind is (V_Implem,           --  not yet implemented
                           V_Slice,            --  array slice
                           V_Discr,            --  discriminant record
                           V_Dispatch,         --  dispatching
                           V_Block_Statement,  --  block declare statement
                           V_Any_Return,       --  return statements
                           V_Any_Exit,         --  exit statements
                           V_Other);           --  other violations of ALFA

   subtype V_Design is Violation_Kind range V_Slice .. V_Other;

   function Is_In_ALFA (Id : Entity_Id) return Boolean;
   --  Return whether a given entity is in ALFA

   function Body_Is_In_ALFA (Id : Entity_Id) return Boolean;
   --  Return whether the body of a given subprogram entity is in ALFA

   procedure Mark_Compilation_Unit (N : Node_Id);
   --  Put marks on a compilation unit. This should be called after all
   --  compilation units on which it depends have been marked.

   procedure Mark_Standard_Package;
   --  Put marks on package Standard

end ALFA.Definition;
