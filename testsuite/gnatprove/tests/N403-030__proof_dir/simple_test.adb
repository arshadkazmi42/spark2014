package body Simple_Test with SPARK_Mode is

   function Test (A : integer) return Integer is
      B : Integer;
      C : integer := 3;
   begin
      if (a = 0) then
         B := 500;
      else
         B := 1000;
      end if;

      C := C + B;

      pragma assert (C > 0);

      return C;
   end;

end Simple_Test;
