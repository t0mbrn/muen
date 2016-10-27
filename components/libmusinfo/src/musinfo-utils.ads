--
--  Copyright (C) 2016  Reto Buerki <reet@codelabs.ch>
--  Copyright (C) 2016  Adrian-Ken Rueegsegger <ken@codelabs.ch>
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

package Musinfo.Utils
is

   --  Return True if Left and Right name data is identical.
   function Name_Data_Equal (Left, Right : Name_Data_Type) return Boolean
   with
      Post => Name_Data_Equal'Result =
                 (for all I in Left'Range => Left (I) = Right (I));

   --  Compare two name types (the default implementation leads to implicit
   --  loops in the expanded generated code).
   function Names_Equal (Left, Right : Name_Type) return Boolean
   with
      Post => Names_Equal'Result = (Left.Length = Right.Length
                                    and Left.Padding = Right.Padding
                                    and Name_Data_Equal
                                       (Left  => Left.Data,
                                        Right => Right.Data));

   --  Convert given name type to string representation.
   procedure To_String
     (Name :        Name_Type;
      Str  : in out String)
   with
      Pre => Str'First = Name.Data'First and Str'Last = Natural (Name.Length);

   --  Compare Count characters of N2 with name type N1. Return True if
   --  characters 1 .. Count are equal.
   function Names_Match
     (N1    : Name_Type;
      N2    : String;
      Count : Name_Size_Type)
      return Boolean
   with
      Pre => Natural (Count) <= N2'Length;

   --  Returns True if the sinfo data is valid.
   function Is_Valid (Sinfo : Subject_Info_Type) return Boolean;

   --  Return subject name stored in subject info data.
   function Subject_Name (Sinfo : Subject_Info_Type) return Name_Type
   with
      Pre => Is_Valid (Sinfo => Sinfo);

   --  Return TSC tick rate in kHz.
   function TSC_Khz (Sinfo : Subject_Info_Type) return TSC_Tick_Rate_Khz_Type
   with
      Pre => Is_Valid (Sinfo => Sinfo);

   --  Return current TSC schedule start value.
   function TSC_Schedule_Start
     (Sinfo : Subject_Info_Type)
      return Interfaces.Unsigned_64
   with
      Pre => Is_Valid (Sinfo => Sinfo);

   --  Return current TSC schedule end value.
   function TSC_Schedule_End
     (Sinfo : Subject_Info_Type)
      return Interfaces.Unsigned_64
   with
       Pre => Is_Valid (Sinfo => Sinfo);

   --  Return memory region with specified name. If no such memory region
   --  exists, Null_Memregion is returned.
   function Memory_By_Name
     (Sinfo : Subject_Info_Type;
      Name  : String)
      return Memregion_Type
   with
      Pre => Is_Valid (Sinfo) and Name'Length <= Name_Index_Type'Last;

   --  Return memory region with specified hash. If no such memory region
   --  exists, Null_Memregion is returned.
   function Memory_By_Hash
     (Sinfo : Subject_Info_Type;
      Hash  : Hash_Type)
      return Memregion_Type
   with
      Pre => Is_Valid (Sinfo => Sinfo);

   --  Memory resource iterator.
   type Memory_Iterator_Type is private;

private

   function Subject_Name (Sinfo : Subject_Info_Type) return Name_Type
   is (Sinfo.Name);

   function TSC_Khz (Sinfo : Subject_Info_Type) return TSC_Tick_Rate_Khz_Type
   is (Sinfo.TSC_Khz);

   function TSC_Schedule_Start
     (Sinfo : Subject_Info_Type)
      return Interfaces.Unsigned_64
   is (Sinfo.TSC_Schedule_Start);

   function TSC_Schedule_End
     (Sinfo : Subject_Info_Type)
      return Interfaces.Unsigned_64
   is (Sinfo.TSC_Schedule_End);

   type Memory_Iterator_Type is record
      Resource_Idx : Resource_Count_Type := No_Resource;
      Owner        : Name_Type           := Null_Name;
   end record;

end Musinfo.Utils;
