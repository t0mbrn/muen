--
--  Copyright (C) 2013, 2014  Reto Buerki <reet@codelabs.ch>
--  Copyright (C) 2013, 2014  Adrian-Ken Rueegsegger <ken@codelabs.ch>
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

generic
package Muchannel.Writer
is

   --- Initialize channel with given epoch.
   procedure Initialize
     (Channel : out Channel_Type;
      Epoch   :     Header_Field_Type)
   with
      Global  => null,
      Depends => (Channel => Epoch);

   --- Deactivate channel.
   procedure Deactivate (Channel : in out Channel_Type)
   with
      Global  => null,
      Depends => (Channel =>+ null);

   --- Test der DokuFunktion
   --- in ``mehreren`` Zeilen
   --- ```
   --- --  Write element to given channel.
   --- declare
   ---      with Muchannel;
   ---      with Ada.Text_IO;
   ---      package Minstance is new Muchannel
   ---       (Element_Type => Integer, Elements => 100, Null_Element => 0,
   ---        Protocol     => 2**64);
   ---
   ---      package Write is new Minstance.Writer;
   ---      with Muchannel.Readers;
   ---      package Read is new Minstance.Readers;
   ---
   ---      Channel : Minstance.Channel_Type;
   ---      Epoch   : Minstance.Header_Field_Type := 69;
   ---
   ---      Type Test_Data is array (0 .. 99) of Integer;
   ---      Test_Array : Test_Data := (0 => 2, others => 0);
   ---
   ---      Result : Integer;
   ---      Reader : Read.Reader_Type;
   ---      ResultT: Read.Result_Type;
   ---
   --- begin
   ---
   ---      Write.Initialize (Channel, Epoch);
   ---      Write.Write(Channel, 2);
   ---
   ---      Read.Read(Channel, Reader, Result, ResultT);
   ---
   ---      Ahven.Assert
   ---      (Condition => Result = 2,
   ---       Message   => "Incorrect Channel Data");
   ---
   --- end;
   --- ```

   procedure Write
     (Channel : in out Channel_Type;
      Element :        Element_Type)
   with
      Global  => null,
      Depends => (Channel =>+ Element);

end Muchannel.Writer;
