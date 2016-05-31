--
--  Copyright (C) 2016  Reto Buerki <reet@codelabs.ch>
--  Copyright (C) 2016  Adrian-Ken Rueegsegger <ken@codelabs.ch>
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

with Ada.Directories;
with Ada.Characters.Handling;

with Mulog;
with Muxml;
with Mutools.Utils;
with Mutools.Templates;

with Cspec.Utils;
with Cspec.Generators;

with String_Templates;

package body Cspec
is

   --  Create template content for component with given name.
   function Create_Template
     (Comp_Name : String;
      Content   : String)
      return Mutools.Templates.Template_Type;

   --  Replace the pattern in the template with the specified content and write
   --  the result to the file given by name. Do nothing if the content string
   --  is empty.
   procedure Create_Child_Package
     (Tmpl     : in out Mutools.Templates.Template_Type;
      Pattern  :        String;
      Content  :        String;
      Filename :        String);

   -------------------------------------------------------------------------

   procedure Create_Child_Package
     (Tmpl     : in out Mutools.Templates.Template_Type;
      Pattern  :        String;
      Content  :        String;
      Filename :        String)
   is
   begin
      if Content'Length = 0 then
         return;
      end if;

      Mutools.Templates.Replace
        (Template => Tmpl,
         Pattern  => Pattern,
         Content  => Content);
      Mutools.Templates.Write
        (Template => Tmpl,
         Filename => Filename);
   end Create_Child_Package;

   -------------------------------------------------------------------------

   function Create_Template
     (Comp_Name : String;
      Content   : String)
      return Mutools.Templates.Template_Type
   is
   begin
      return T : Mutools.Templates.Template_Type do
         T := Mutools.Templates.Create (Content => Content);
         Mutools.Templates.Replace
           (Template => T,
            Pattern  => "__component_name__",
            Content  => Mutools.Utils.To_Ada_Identifier (Str => Comp_Name));
      end return;
   end Create_Template;

   -------------------------------------------------------------------------

   procedure Run
     (Policy_File      : String;
      Component_Name   : String;
      Output_Directory : String)
   is
      Policy : Muxml.XML_Data_Type;
   begin
      Mulog.Log (Msg => "Generating '" & Component_Name & "' component specs "
                 & "in '" & Output_Directory & "' directory");

      Muxml.Parse (Data => Policy,
                   Kind => Muxml.Format_Src,
                   File => Policy_File);
      Mulog.Log (Msg => "Processing policy '" & Policy_File & "'");

      if not Utils.Is_Present
        (Policy    => Policy,
         Comp_Name => Component_Name)
      then
         raise Component_Not_Found with "Component '" & Component_Name
           & "' not found in the policy";
      end if;

      declare
         Tmpl            : Mutools.Templates.Template_Type;
         Comp_Name_Lower : constant String
           := Ada.Characters.Handling.To_Lower (Item => Component_Name);
         Fname_Base      : constant String
           := Output_Directory & "/" & Comp_Name_Lower & "_component";
         Memory : constant String
           := Generators.Get_Memory_Str
             (Policy    => Policy,
              Comp_Name => Component_Name);
         Channels : constant String
           := Generators.Get_Channels_Str
             (Policy    => Policy,
              Comp_Name => Component_Name);
      begin
         if Memory'Length = 0 and then Channels'Length = 0 then
            Mulog.Log (Msg => "No resources found, nothing to do");
            return;
         end if;

         if not Ada.Directories.Exists (Name => Output_Directory) then
            Ada.Directories.Create_Path (New_Directory => Output_Directory);
         end if;

         Mutools.Templates.Write
           (Template => Create_Template
              (Comp_Name => Component_Name,
               Content   => String_Templates.component_ads),
            Filename => Fname_Base & ".ads");

         Tmpl := Create_Template
           (Comp_Name => Component_Name,
            Content   => String_Templates.component_memory_ads);
         Create_Child_Package
           (Tmpl     => Tmpl,
            Pattern  => "__memory__",
            Content  => Memory,
            Filename => Fname_Base & "-memory.ads");

         Tmpl := Create_Template
           (Comp_Name => Component_Name,
            Content   => String_Templates.component_channels_ads);
         Create_Child_Package
           (Tmpl     => Tmpl,
            Pattern  => "__channels__",
            Content  => Channels,
            Filename => Fname_Base & "-channels.ads");

         Mulog.Log (Msg => "Specs generated successfully");
      end;
   end Run;

end Cspec;
