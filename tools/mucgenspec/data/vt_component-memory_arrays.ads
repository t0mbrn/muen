pragma Style_Checks (Off);

package Vt_Component.Memory_Arrays
is

   Memarray_Address_Base  : constant := 16#5000#;
   Memarray_Element_Size  : constant := 16#1000#;
   Memarray_Element_Count : constant := 2;
   Memarray_Executable    : constant Boolean := True;
   Memarray_Writable      : constant Boolean := False;

   Memarray_Names : constant Name_Array (1 .. Memarray_Element_Count)
     := (
         1 => To_Name (Str => "mem1"),
         2 => To_Name (Str => "mem2")
        );

   Empty_Memarray_Address_Base  : constant := 16#f000#;
   Empty_Memarray_Element_Size  : constant := 16#1000#;
   Empty_Memarray_Element_Count : constant := 0;
   Empty_Memarray_Executable    : constant Boolean := False;
   Empty_Memarray_Writable      : constant Boolean := False;

   Empty_Memarray_Names : constant Name_Array (1 .. Empty_Memarray_Element_Count)
     := (
         others => To_Name (Str => "")
        );

end Vt_Component.Memory_Arrays;
