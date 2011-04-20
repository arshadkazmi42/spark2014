function P (X, Y, Z : in Integer) return Integer is

   function Id (X : Integer) return Integer
     with Post => Id'Result - X = 0;

   function Id (X : Integer) return Integer is
   begin
      return X;
   end Id;

begin
   if not( (X >= 10) and then
     Y > 0 and then
     Z < 0 and then
     (Y + Z <= 100) and then
     (X <= 1000) ) then
      return 0;
   end if;

   for K in 1 .. 10 loop
      pragma Assert (X >= K);
      if Y > K then
         return X;
      end if;
      exit when Z > K;
   end loop;

   for K in 1 .. 10 loop
      pragma Assert (X >= K);
      if Y > K then
         if Z > K then
            return Y;
         end if;
      end if;
   end loop;

   Outter : for H in 1 .. 10 loop
      for K in 1 .. 10 loop
         pragma Assert (X >= K);
         if Y > K then
            if Z > K then
               return Y;
            end if;
         end if;
      end loop;
   end loop Outter;

   return X + (Y + Z);
end;
