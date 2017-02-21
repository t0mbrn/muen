--  This package has been generated automatically by GNATtest.
--  You are allowed to add your code to the bodies of test routines.
--  Such changes will be kept during further regeneration of this file.
--  All code placed outside of test routine bodies will be lost. The
--  code intended to set up and tear down the test environment should be
--  placed into Compjoin.Test_Data.

with AUnit.Assertions; use AUnit.Assertions;
with System.Assertions;

package body Compjoin.Test_Data.Tests is


--  begin read only
   procedure Test_Run (Gnattest_T : in out Test);
   procedure Test_Run_e5a2dd (Gnattest_T : in out Test) renames Test_Run;
--  id:2.2/e5a2dd86b12d7902/Run/1/0/
   procedure Test_Run (Gnattest_T : in out Test) is
   --  compjoin.ads:25:4:Run
--  end read only

      pragma Unreferenced (Gnattest_T);

   begin
      Run
        (Input_File     => "data/test_policy.xml",
         Output_File    => "obj/joined_policy.xml",
         Component_List => "data/library_debug.xml,data/component_debug.xml");
      Assert (Condition => Test_Utils.Equal_Files
              (Filename1 => "data/policy_joined.ref.xml",
               Filename2 => "obj/joined_policy.xml"),
              Message   => "Joined policy mismatch");
      Ada.Directories.Delete_File (Name => "obj/joined_policy.xml");

      Ada.Directories.Copy_File (Source_Name => "data/test_policy.xml",
                                 Target_Name => "obj/in_place_join.xml");
      Run
        (Input_File     => "obj/in_place_join.xml",
         Output_File    => "obj/in_place_join.xml",
         Component_List => "data/library_debug.xml,data/component_debug.xml");
      Assert (Condition => Test_Utils.Equal_Files
              (Filename1 => "data/policy_joined.ref.xml",
               Filename2 => "obj/in_place_join.xml"),
              Message   => "In-place joined policy mismatch");
      Ada.Directories.Delete_File (Name => "obj/in_place_join.xml");
--  begin read only
   end Test_Run;
--  end read only

end Compjoin.Test_Data.Tests;
