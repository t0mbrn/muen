with Muchannel;

package Minstance is new Muchannel
      (Element_Type => Integer,
       Elements     => 100,
       Null_Element => 0,
       Protocol     => 2**64);

--- ```
--- -- Returns True if the channel is currently active.
--- declare
---      Header  : Header_Type := (1,2,3,4,5,6,7,8);
---      Data    : Data_Type := (others => 0);
---      Channel : Channel_Type := (Header, Data));
---      Result  : False;
--- begin
---      Is_Active (Channel, Result)
---
---      Ahven.Assert
---       (Condition => Result = True,
---        Message   => "Channel was not found to be active.");
--- end;
--- ```
-- FIXME  in declare nochmal instanziieren?