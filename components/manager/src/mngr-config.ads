--
--  Copyright (C) 2020  Reto Buerki <reet@codelabs.ch>
--  Copyright (C) 2020  Adrian-Ken Rueegsegger <ken@codelabs.ch>
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

with Interfaces;

with Mucontrol.Command;

package Mngr.Config
is

   type Subject_Dependency_Type is record
      Dep_ID    : Subjects_Range;
      Dep_State : Run_State_Type;
   end record;

   No_Dep : constant Subject_Dependency_Type
     := (Dep_ID    => No_Subject,
         Dep_State => FSM_Initial);

   type Subject_Deps_Type is array (1 .. 4) of Subject_Dependency_Type;

   type Subject_Config_Type is record
      Self_Governed : Boolean;
      Initial_Erase : Boolean;
      WD_Interval   : Interfaces.Unsigned_64;
      Run_Deps      : Subject_Deps_Type;
   end record;

   type Subject_Configs_Type is array (Managed_Subjects_Range)
     of Subject_Config_Type;

   Instance : constant Subject_Configs_Type
     := (1 => (Self_Governed => True,
               Initial_Erase => False,
               WD_Interval   => Mucontrol.Command.WD_DISABLED,
               Run_Deps      => (others => No_Dep)),
         2 => (Self_Governed => False,
               Initial_Erase => True,
               WD_Interval   => Mucontrol.Command.WD_DISABLED,
               Run_Deps          =>
                 (1      => (Dep_ID    => 1,
                             Dep_State => FSM_Finished),
                  others => No_Dep)),
         3 => (Self_Governed => True,
               Initial_Erase => False,
               WD_Interval   => Mucontrol.Command.WD_DISABLED,
               Run_Deps      =>
                 (1      => (Dep_ID    => 1,
                             Dep_State => FSM_Finished),
                  others => No_Dep)),
         4 => (Self_Governed => False,
               Initial_Erase => True,
               WD_Interval   => Mucontrol.Command.WD_DISABLED,
               Run_Deps      =>
                 (1      => (Dep_ID    => 1,
                             Dep_State => FSM_Finished),
                  others => No_Dep)));

end Mngr.Config;
