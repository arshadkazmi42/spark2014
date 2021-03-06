------------------------------------------------------------------------------
--                                                                          --
--                           GNAT2WHY COMPONENTS                            --
--                                                                          --
--                     F L O W _ V I S I B I L I T Y                        --
--                                                                          --
--                                S p e c                                   --
--                                                                          --
--                   Copyright (C) 2018, Altran UK Limited                  --
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
------------------------------------------------------------------------------

with Flow_Types; use Flow_Types;
with Types;      use Types;

package Flow_Visibility is

   --  The visibility graph is created in two passes: first vertices, then
   --  edges, because frontend doesn't provide a realiable routine that would
   --  traverse declarations before references.

   procedure Register_Flow_Scopes (Unit_Node : Node_Id);
   --  Creates vertices in the visibility graph

   procedure Connect_Flow_Scopes;
   --  Creates edges in the visibility graph

   function Is_Visible
     (Looking_From : Flow_Scope;
      Looking_At   : Flow_Scope)
      return Boolean;
   --  Returns True iff Looking_From has visibility of Looking_At

end Flow_Visibility;
