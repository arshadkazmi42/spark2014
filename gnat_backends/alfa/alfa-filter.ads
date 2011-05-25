------------------------------------------------------------------------------
--                                                                          --
--                         GNAT BACK-END COMPONENTS                         --
--                                                                          --
--                           A L F A . F I L T E R                          --
--                                                                          --
--                                 S p e c                                  --
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

with Ada.Containers;                     use Ada.Containers;
with Ada.Containers.Doubly_Linked_Lists;
with String_Utils; use String_Utils;

package ALFA.Filter is

   package List_Of_Nodes is new Doubly_Linked_Lists (Node_Id);
   --  Standard list of nodes. It is better to use these, as a Node_Id can be
   --  in any number of these lists, while it can be only in one List_Id.

   type Why_Package_Kind is (WPK_Subprogram, WPK_Package);
   type Why_Package is
      record
         WP_Name    : access String;
         WP_Context : String_Lists.List;
         WP_Decls   : List_Of_Nodes.List;
      end record;

   package List_Of_Why_Packs is new Doubly_Linked_Lists (Why_Package);

   ALFA_Compilation_Units : List_Of_Why_Packs.List;

   procedure Filter_Compilation_Unit (N : Node_Id);
   --  Filter declarations in compilation unit N and generate compilation units
   --  which are appended to Compilation_Units.

   function Filter_Standard_Package return List_Of_Nodes.List;
   --  Return filtered standard package node

end ALFA.Filter;
