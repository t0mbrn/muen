--
--  Copyright (C) 2019  Reto Buerki <reet@codelabs.ch>
--  Copyright (C) 2019  Adrian-Ken Rueegsegger <ken@codelabs.ch>
--
--  This program is free software: you can redistribute it and/or modify
--  it under the terms of the GNU General Public License as published by
--  the Free Software Foundation, either version 3 of the License, or
--  (at your option) any later version.
--
--  This program is distributed in the hope that it will be useful,
--  but WITHOUT ANY WARRANTY; without even the implied warranty of
--  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
--  GNU General Public License for more details.
--
--  You should have received a copy of the GNU General Public License
--  along with this program.  If not, see <http://www.gnu.org/licenses/>.
--

with Ada.Strings.Unbounded;

with Interfaces;

with Muxml;

private with DOM.Core;

package Cmd_Stream.XML_Utils
is

   --  Command stream document type
   type Stream_Document_Type is new Muxml.XML_Data_Type with null record;

   --  Create command stream document with given filename.
   procedure Create
     (Stream_Doc : out Stream_Document_Type;
      Filename   :     String);

   --  Command stream command attribute, value pair.
   type Attribute_Type is record
      Attr, Value : Ada.Strings.Unbounded.Unbounded_String;
   end record;

   Null_Attr : constant Attribute_Type;

   type Attribute_Array is array (Positive range <>) of Attribute_Type;

   Null_Attrs : constant Attribute_Array;

   type Command_Buffer_Type is private;

   --  Reverse order of commands in the given buffer.
   procedure Reverse_Commands (Buffer : in out Command_Buffer_Type);

   --  Append command with given name and attributes to the specified command
   --  stream document.
   procedure Append_Command
     (Stream_Doc : in out Stream_Document_Type;
      Name       :        String;
      Attrs      :        Attribute_Array := Null_Attrs);

   --  Append command with given name and attributes to the specified command
   --  buffer which is part of the designated stream document.
   procedure Append_Command
     (Buffer     : in out Command_Buffer_Type;
      Stream_Doc :        Stream_Document_Type;
      Name       :        String;
      Attrs      :        Attribute_Array := Null_Attrs);

   --  Append commands from given buffer to the specified command stream
   --  document.
   procedure Append_Commands
     (Stream_Doc : in out Stream_Document_Type;
      Buffer     :        Command_Buffer_Type);

   --  Generate command stream to clear memory region specified by base address
   --  and size.
   procedure Clear_Region
     (Stream_Doc   : in out Stream_Document_Type;
      Base_Address :        Interfaces.Unsigned_64;
      Size         :        Interfaces.Unsigned_64);

   --  Write given commando stream to file specified by name.
   procedure Write
     (Stream_Doc : in out Stream_Document_Type;
      Filename   :        String);

private

   type Command_Buffer_Type is new DOM.Core.Node_List;

   Null_Attr : constant Attribute_Type
     := (Attr  => Ada.Strings.Unbounded.Null_Unbounded_String,
         Value => Ada.Strings.Unbounded.Null_Unbounded_String);

   Null_Attrs : constant Attribute_Array (1 .. 0)
     := (others => Null_Attr);

end Cmd_Stream.XML_Utils;
