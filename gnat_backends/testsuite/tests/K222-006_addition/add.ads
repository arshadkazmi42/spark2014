package Add is
   function AddTwo (X, Y : Integer) return Integer;
      Pragma Precondition (Integer'First <= X + Y and X + Y <= Integer'Last);
      Pragma Postcondition (AddTwo'Result = X + Y);
end Add;
