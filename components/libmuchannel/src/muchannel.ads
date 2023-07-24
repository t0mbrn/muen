--
--  Copyright (C) 2013-2015  Reto Buerki <reet@codelabs.ch>
--  Copyright (C) 2013-2015  Adrian-Ken Rueegsegger <ken@codelabs.ch>
--  All rights reserved.
--
--  Redistribution and use in source and binary forms, with or without
--  modification, are permitted provided that the following conditions are met:
--
--    * Redistributions of source code must retain the above copyright notice,
--      this list of conditions and the following disclaimer.
--
--    * Redistributions in binary form must reproduce the above copyright
--      notice, this list of conditions and the following disclaimer in the
--      documentation and/or other materials provided with the distribution.
--
--  THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
--  AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
--  IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
--  ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE
--  LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
--  CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
--  SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
--  INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
--  CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
--  ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
--  POSSIBILITY OF SUCH DAMAGE.
--

with Interfaces;

with Muchannel_Constants;

--  Muen shared memory channels.
--
--  Muen shared memory channels are an implementation of the SHMStream
--  Version 2 IPC protocol (shmstream) as specified by 'SHMStream Version 2 IPC
--  Interface', Robert Dorn, 2013, unpublished.
generic

   --  Elements transported via channel instance.
   type Element_Type is private;

   --  Capacity of channel in number of elements.
   Elements : Positive;

   --  Null element.
   Null_Element : Element_Type;

   --  Protocol identifier.
   Protocol : Interfaces.Unsigned_64;

package Muchannel is

   --  Communication channel used by reader and writer.
   type Channel_Type is limited private;

   --  Type of channel header fields.
   type Header_Field_Type is mod 2 ** 64;

   --- ```
   --- -- Returns True if the channel is currently active.
   --- declare
   ---      with Muchannel.Writer;
   ---      package Minstance is new Muchannel
   ---       (Element_Type => Integer, Elements => 100, Null_Element => 0,
   ---        Protocol     => 2**64);
   ---
   ---      package Write is new Minstance.Writer;
   ---
   ---
   ---      Channel : Minstance.Channel_Type;
   ---      Epoch   : Minstance.Header_Field_Type := 69;
   ---
   ---      Result  : Boolean := False;
   --- begin
   ---
   ---      Write.Initialize (Channel, Epoch);
   ---      Write.Write(Channel, 2);
   ---
   ---      Minstance.Is_Active (Channel, Result);
   ---
   ---      Ahven.Assert
   ---       (Condition => Result,
   ---        Message   => "Channel was not found to be active.");
   --- end;
   --- ```

   procedure Is_Active
     (Channel :     Channel_Type;
      Result  : out Boolean)
   with
      Global  => null,
      Depends => (Result => Channel);

private

   --  "SHMStream20=", base64-encoded.
   SHMStream_Marker : constant := 16#4873_12b6_b79a_9b6d#;

   for Header_Field_Type'Size use 64;

   Element_Size : constant Header_Field_Type
     := Header_Field_Type'Mod (Element_Type'Size / 8);

   --  Channel header as specified by SHMStream v2 protocol.
   type Header_Type is record
      Transport : Header_Field_Type with Atomic;
      Epoch     : Header_Field_Type with Atomic;
      Protocol  : Header_Field_Type;
      Size      : Header_Field_Type;
      Elements  : Header_Field_Type;
      Reserved  : Header_Field_Type;
      WSC       : Header_Field_Type with Atomic;
      WC        : Header_Field_Type with Atomic;
   end record
     with Alignment => 64,
          Size      => 8 * Muchannel_Constants.Header_Size;

   for Header_Type use record
      Transport at  0 range 0 .. 63;
      Epoch     at  8 range 0 .. 63;
      Protocol  at 16 range 0 .. 63;
      Size      at 24 range 0 .. 63;
      Elements  at 32 range 0 .. 63;
      Reserved  at 40 range 0 .. 63;
      WSC       at 48 range 0 .. 63;
      WC        at 56 range 0 .. 63;
   end record;

   --  Channel data stored as array of elements.
   type Data_Range is new Natural range 0 .. Elements - 1;
   type Data_Type  is array (Data_Range) of Element_Type
     with Pack;

   type Channel_Type is record
      Header : Header_Type;
      Data   : Data_Type;
   end record
     with Volatile, Pack;

   --  Null epoch used for inactive/disabled channels.
   Null_Epoch : constant Header_Field_Type := 0;

end Muchannel;
