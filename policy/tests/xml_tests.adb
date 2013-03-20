with Ada.Exceptions;
with Ada.Strings.Unbounded;

with SK;

with Skp.Xml;

package body Xml_Tests
is

   use Ahven;
   use Skp;

   -------------------------------------------------------------------------

   procedure Initialize (T : in out Testcase)
   is
   begin
      T.Set_Name (Name => "XML tests");
      T.Add_Test_Routine
        (Routine => Load_Nonexistent_Xsd'Access,
         Name    => "Load nonexistent XSD");
      T.Add_Test_Routine
        (Routine => Load_Invalid_Xsd'Access,
         Name    => "Load invalid XSD");
      T.Add_Test_Routine
        (Routine => Load_Nonexistent_Xml'Access,
         Name    => "Load nonexistent XML");
      T.Add_Test_Routine
        (Routine => Load_Invalid_Xml'Access,
         Name    => "Load invalid XML");
      T.Add_Test_Routine
        (Routine => Load_Policy_Xml'Access,
         Name    => "Load policy from XML");
      T.Add_Test_Routine
        (Routine => Xml_To_Policy'Access,
         Name    => "Deserialize Ada policy type");
   end Initialize;

   -------------------------------------------------------------------------

   procedure Load_Invalid_Xml
   is
      Data    : Xml.XML_Data_Type;
      Ref_Msg : constant String := "Error reading XML file 'data/invalid' - "
        & "data/invalid:1:1: Non-white space found at top level";
   begin
      Xml.Parse (Data   => Data,
                 File   => "data/invalid",
                 Schema => "schema/system.xsd");

   exception
      when E : Xml.Processing_Error =>
         Assert (Condition => Ada.Exceptions.Exception_Message
                 (X => E) = Ref_Msg,
                 Message   => "Exception message mismatch");
   end Load_Invalid_Xml;

   -------------------------------------------------------------------------

   procedure Load_Invalid_Xsd
   is
      Data    : Xml.XML_Data_Type;
      Ref_Msg : constant String := "Error reading XSD file 'data/invalid' - "
        & "data/invalid:1:1: Non-white space found at top level";
   begin
      Xml.Parse (Data   => Data,
                 File   => "examples/test_policy1.xml",
                 Schema => "data/invalid");

   exception
      when E : Xml.Processing_Error =>
         Assert (Condition => Ada.Exceptions.Exception_Message
                 (X => E) = Ref_Msg,
                 Message   => "Exception message mismatch");
   end Load_Invalid_Xsd;

   -------------------------------------------------------------------------

   procedure Load_Nonexistent_Xml
   is
      Data    : Xml.XML_Data_Type;
      Ref_Msg : constant String
        := "Error reading XML file 'nonexistent' - Could not open nonexistent";
   begin
      Xml.Parse (Data   => Data,
                 File   => "nonexistent",
                 Schema => "schema/system.xsd");

   exception
      when E : Xml.Processing_Error =>
         Assert (Condition => Ada.Exceptions.Exception_Message
                 (X => E) = Ref_Msg,
                 Message   => "Exception message mismatch");
   end Load_Nonexistent_Xml;

   -------------------------------------------------------------------------

   procedure Load_Nonexistent_Xsd
   is
      Data    : Xml.XML_Data_Type;
      Ref_Msg : constant String
        := "Error reading XSD file 'nonexistent' - Could not open nonexistent";
   begin
      Xml.Parse (Data   => Data,
                 File   => "examples/test_policy1.xml",
                 Schema => "nonexistent");

   exception
      when E : Xml.Processing_Error =>
         Assert (Condition => Ada.Exceptions.Exception_Message
                 (X => E) = Ref_Msg,
                 Message   => "Exception message mismatch");
   end Load_Nonexistent_Xsd;

   -------------------------------------------------------------------------

   procedure Load_Policy_Xml
   is
      Data : Xml.XML_Data_Type;
   begin
      Xml.Parse (Data   => Data,
                 File   => "data/test_policy1.xml",
                 Schema => "schema/system.xsd");

      --  Must not raise an exception.

   end Load_Policy_Xml;

   -------------------------------------------------------------------------

   procedure Xml_To_Policy
   is
      use Ada.Strings.Unbounded;

      D : Xml.XML_Data_Type;
      P : Policy_Type;

      Iterate_Count : Natural := 0;
      procedure Inc_Iterate_Counter (S : Subject_Type)
      is
         pragma Unreferenced (S);
      begin
         Iterate_Count := Iterate_Count + 1;
      end Inc_Iterate_Counter;
   begin
      Xml.Parse (Data   => D,
                 File   => "data/test_policy1.xml",
                 Schema => "schema/system.xsd");
      P := Xml.To_Policy (Data => D);
      Assert (Condition => Get_Subject_Count (Policy => P) = 3,
              Message   => "Subject count mismatch");

      Iterate (Policy  => P,
               Process => Inc_Iterate_Counter'Access);
      Assert (Condition => Iterate_Count = Get_Subject_Count (Policy => P),
              Message   => "Iterate count mismatch");

      begin
         declare
            S : constant Subject_Type := Get_Subject
              (Policy => P,
               Id     => 255);
            pragma Unreferenced (S);
         begin
            Fail (Message => "Exception expected");
         end;

      exception
         when Subject_Not_Found => null;
      end;

      declare
         use type SK.Word64;

         S : constant Subject_Type := Get_Subject
           (Policy => P,
            Id     => 0);
         M : Memory_Layout_Type;
      begin
         Assert (Condition => Get_Id (Subject => S) = 0,
                 Message   => "Id mismatch");
         Assert (Condition => Get_Name (Subject => S) = To_Unbounded_String
                 (Source => "tau0"),
                 Message   => "Name mismatch");

         M := Get_Memory_Layout (Subject => S);
         Assert (Condition => Get_Pml4_Address (Layout => M) = 2031616,
                 Message   => "PML4 address mismatch");
      end;
   end Xml_To_Policy;

end Xml_Tests;
