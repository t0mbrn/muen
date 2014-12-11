--
--  Copyright (C) 2014  secunet Security Networks AG
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

package Debuglog.Client
with
   Abstract_State => State,
   Initializes    => State
is

   subtype Byte is Interfaces.Unsigned_8;
   subtype Word16 is Interfaces.Unsigned_16;
   subtype Word32 is Interfaces.Unsigned_32;
   subtype Word64 is Interfaces.Unsigned_64;

   --  Write character.
   procedure Put (Item : Character)
   with
      Global  => (In_Out => State),
      Depends => (State =>+ Item);

   --  Write string.
   procedure Put (Item : String)
   with
      Global  => (In_Out => State),
      Depends => (State =>+ Item);

   --  Write boolean.
   procedure Put (Item : Boolean)
   with
      Global  => (In_Out => State),
      Depends => (State =>+ Item);

   --  Write string and start new line.
   procedure Put_Line (Item : String)
   with
      Global  => (In_Out => State),
      Depends => (State =>+ Item);

   --  Start new line.
   procedure New_Line
   with
      Global  => (In_Out => State),
      Depends => (State =>+ null);

   --  Write string if condition is true.
   procedure Put_If
     (Condition : Boolean;
      Item      : String)
   with
      Global  => (In_Out => State),
      Depends => (State =>+ (Condition, Item));

   --  Write Byte.
   procedure Put_Byte (Item : Byte)
   with
      Global  => (In_Out => State),
      Depends => (State =>+ Item);

   --  Write Word16.
   procedure Put_Word16 (Item : Word16)
   with
      Global  => (In_Out => State),
      Depends => (State =>+ Item);

   --  Write Word32.
   procedure Put_Word32 (Item : Word32)
   with
      Global  => (In_Out => State),
      Depends => (State =>+ Item);

   --  Write Word64.
   procedure Put_Word64 (Item : Word64)
   with
      Global  => (In_Out => State),
      Depends => (State =>+ Item);

   --  Write UInt64 as decimal value.
   procedure Put_UInt64 (Item : Word64)
   with
      Global  => (In_Out => State),
      Depends => (State =>+ Item);

   --  Write string and Byte and start new line.
   procedure Put_Reg8
     (Name  : String;
      Value : Byte)
   with
      Global  => (In_Out => State),
      Depends => (State =>+ (Name, Value));

   --  Write string and Word16 and start new line.
   procedure Put_Reg16
     (Name  : String;
      Value : Word16)
   with
      Global  => (In_Out => State),
      Depends => (State =>+ (Name, Value));

   --  Write string and Word32 and start new line.
   procedure Put_Reg32
     (Name  : String;
      Value : Word32)
   with
      Global  => (In_Out => State),
      Depends => (State =>+ (Name, Value));

   --  Write string and Word64 and start new line.
   procedure Put_Reg64
     (Name  : String;
      Value : Word64)
   with
      Global  => (In_Out => State),
      Depends => (State =>+ (Name, Value));

   --  Flush buffers.
   procedure Flush
   with
      Global  => (In_Out => State),
      Depends => (State =>+ null);

end Debuglog.Client;
