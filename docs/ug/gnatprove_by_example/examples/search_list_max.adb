with Loop_Types; use Loop_Types; use Loop_Types.Lists;

procedure Search_List_Max (L : List_T; Pos : out Cursor; Max : out Component_T) with
  SPARK_Mode,
  Pre  => not Is_Empty (L),
  Post => (for all E of L => E <= Max) and then
          (for some E of L => E = Max) and then
          Has_Element (L, Pos) and then
          Element (L, Pos) = Max
is
   Cu : Cursor := First (L);
begin
   Max := 0;
   Pos := Cu;

   while Has_Element (L, Cu) loop
      pragma Loop_Invariant (for all Cu2 in First_To_Previous (L, Cu) => Element (L, Cu2) <= Max);
      pragma Loop_Invariant (Max = 0 or else (for some Cu2 in First_To_Previous (L, Cu) => Element (L, Cu2) = Max));
      pragma Loop_Invariant (Has_Element (L, Pos));
      pragma Loop_Invariant (Max = 0 or else Element (L, Pos) = Max);

      if Element (L, Cu) > Max then
         Max := Element (L, Cu);
         Pos := Cu;
      end if;
      Next (L, Cu);
   end loop;
end Search_List_Max;
