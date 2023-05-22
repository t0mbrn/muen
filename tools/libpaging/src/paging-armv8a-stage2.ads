--
--  Copyright (C) 2023  Reto Buerki <reet@codelabs.ch>
--  Copyright (C) 2023  Adrian-Ken Rueegsegger <ken@codelabs.ch>
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

with Ada.Streams;

with Paging.Entries;
with Paging.Tables;

package Paging.ARMv8a.Stage2
is

   --  Implementation of ARMv8a stage 2 paging structures, as specified by Arm
   --  Architecture Reference Manual for A-profile architecture,
   --  issue J.a, "D8.3 Translation table descriptor formats".

   procedure Serialize_Level0
     (Stream : not null access Ada.Streams.Root_Stream_Type'Class;
      Table  : Tables.Page_Table_Type);

   procedure Serialize_Level1
     (Stream : not null access Ada.Streams.Root_Stream_Type'Class;
      Table  : Tables.Page_Table_Type);

   procedure Serialize_Level2
     (Stream : not null access Ada.Streams.Root_Stream_Type'Class;
      Table  : Tables.Page_Table_Type);

   procedure Serialize_Level3
     (Stream : not null access Ada.Streams.Root_Stream_Type'Class;
      Table  : Tables.Page_Table_Type);

   --  Create single Level0 entry from given stream data.
   procedure Deserialize_Level0_Entry
     (Stream      : not null access Ada.Streams.Root_Stream_Type'Class;
      Table_Entry : out Entries.Table_Entry_Type);

   --  Create single level1 entry from given stream data.
   procedure Deserialize_Level1_Entry
     (Stream      : not null access Ada.Streams.Root_Stream_Type'Class;
      Table_Entry : out Entries.Table_Entry_Type);

   --  Create single level2 entry from given stream data.
   procedure Deserialize_Level2_Entry
     (Stream      : not null access Ada.Streams.Root_Stream_Type'Class;
      Table_Entry : out Entries.Table_Entry_Type);

   --  Create single level3 entry from given stream data.
   procedure Deserialize_Level3_Entry
     (Stream      : not null access Ada.Streams.Root_Stream_Type'Class;
      Table_Entry : out Entries.Table_Entry_Type);

private

   --  Convert given ARMv8a stage2 memory attributes numeric value to caching
   --  type representation. Raises constraint error if an invalid value is
   --  provided.
   function Cache_Mapping
     (ARMv8a_Stage2_Memory_Attrs : Interfaces.Unsigned_64)
      return Caching_Type;

end Paging.ARMv8a.Stage2;
