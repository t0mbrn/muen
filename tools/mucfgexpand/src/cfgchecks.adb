--
--  Copyright (C) 2014  Reto Buerki <reet@codelabs.ch>
--  Copyright (C) 2014  Adrian-Ken Rueegsegger <ken@codelabs.ch>
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

with Ada.Exceptions;
with Ada.Containers.Hashed_Sets;
with Ada.Strings.Unbounded.Hash;

with Interfaces;

with DOM.Core.Nodes;
with DOM.Core.Append_Node;
with DOM.Core.Elements;

with McKae.XML.XPath.XIA;

with Mulog;
with Muxml.Utils;
with Mucfgcheck.Validation_Errors;
with Mutools.Match;
with Mutools.Utils;
with Mutools.XML_Utils;

package body Cfgchecks
is

   --  Check the existence of channel endpoint (reader or writer) event
   --  attributes given by name. The XPath query specifies which global
   --  channels should be checked.
   procedure Check_Channel_Endpoint_Events_Attr
     (XML_Data  : Muxml.XML_Data_Type;
      XPath     : String;
      Endpoint  : String;
      Attr_Name : String);

   --  Check the existence of physical channel hasEvent attributes for channel
   --  reader/writer endpoints which specify event ID or vector.
   procedure Check_Channel_Has_Event_Attr
     (XML_Data  : Muxml.XML_Data_Type;
      Endpoint  : String;
      Attr_Name : String);

   procedure No_Check
     (Logical_Resource  : DOM.Core.Node;
      Physical_Resource : DOM.Core.Node;
      Mapping           : DOM.Core.Node) is null;

   --  Check subject mappings of given logical component resources against
   --  specified physical resources. The specified additional check is invoked
   --  after the basic checks are successful. By default no additional checks
   --  are performed.
   procedure Check_Component_Resource_Mappings
     (Logical_Resources  : DOM.Core.Node_List;
      Physical_Resources : DOM.Core.Node_List;
      Resource_Type      : String;
      Subject            : DOM.Core.Node;
      Additional_Check   : not null access procedure
        (Logical_Resource  : DOM.Core.Node;
         Physical_Resource : DOM.Core.Node;
         Mapping           : DOM.Core.Node) := No_Check'Access);

   --  Calls the Check_Resources procedure for each component resource with
   --  the corresponding physical resource as parameter.
   procedure Check_Component_Resources
     (Logical_Resources  : DOM.Core.Node_List;
      Physical_Resources : DOM.Core.Node_List;
      Subject            : DOM.Core.Node;
      Check_Resource     : not null access procedure
        (Logical_Resource  : DOM.Core.Node;
         Physical_Resource : DOM.Core.Node));

   --  The procedure checks for all existing subjects in the specified policy
   --  that a given attribute of component resource mappings is unique
   --  per-subject.
   procedure Check_Subject_Resource_Maps_Attr_Uniqueness
     (XML_Data : Muxml.XML_Data_Type;
      Attr     : String);

   --  Checks the uniqueness of the specified attribute for all given nodes.
   --  The specified description is used in exception and log messages.
   procedure Check_Attribute_Uniqueness
     (Nodes       : DOM.Core.Node_List;
      Attr_Name   : String;
      Description : String);

   --  Returns True if the left node's 'ref' attribute matches the 'name'
   --  attribute of the right node.
   function Match_Ref_Name (Left, Right : DOM.Core.Node) return Boolean;

   -------------------------------------------------------------------------

   procedure Channel_Reader_Has_Event_Vector (XML_Data : Muxml.XML_Data_Type)
   is
   begin
      Check_Channel_Endpoint_Events_Attr
        (XML_Data  => XML_Data,
         XPath     => "/system/channels/channel[@hasEvent!='switch']",
         Endpoint  => "reader",
         Attr_Name => "vector");
      Check_Channel_Has_Event_Attr
        (XML_Data  => XML_Data,
         Endpoint  => "reader",
         Attr_Name => "vector");
   end Channel_Reader_Has_Event_Vector;

   -------------------------------------------------------------------------

   procedure Channel_Reader_Writer (XML_Data : Muxml.XML_Data_Type)
   is
      Channels : constant DOM.Core.Node_List
        := McKae.XML.XPath.XIA.XPath_Query
          (N     => XML_Data.Doc,
           XPath => "/system/channels/channel");
      Readers  : constant DOM.Core.Node_List
        := McKae.XML.XPath.XIA.XPath_Query
          (N     => XML_Data.Doc,
           XPath => "/system/subjects/subject/channels/reader");
      Writers  : constant DOM.Core.Node_List
        := McKae.XML.XPath.XIA.XPath_Query
          (N     => XML_Data.Doc,
           XPath => "/system/subjects/subject/channels/writer");
   begin
      Mulog.Log (Msg => "Checking" & DOM.Core.Nodes.Length
                 (List => Channels)'Img & " channel(s) for reader/writer "
                 & "count");
      for I in 0 .. DOM.Core.Nodes.Length (List => Channels) - 1 loop
         declare
            Channel      : constant DOM.Core.Node
              := DOM.Core.Nodes.Item
                (List  => Channels,
                 Index => I);
            Channel_Name : constant String
              := DOM.Core.Elements.Get_Attribute
                (Elem => Channel,
                 Name => "name");
            Has_Event    : constant String
              := DOM.Core.Elements.Get_Attribute
                (Elem => Channel,
                 Name => "hasEvent");
            Reader_Count : constant Natural
              := DOM.Core.Nodes.Length
                (List => Muxml.Utils.Get_Elements
                   (Nodes     => Readers,
                    Ref_Attr  => "physical",
                    Ref_Value => Channel_Name));
            Writer_Count : constant Natural
              := DOM.Core.Nodes.Length
                (List => Muxml.Utils.Get_Elements
                   (Nodes     => Writers,
                    Ref_Attr  => "physical",
                    Ref_Value => Channel_Name));
         begin
            if (Has_Event'Length > 0 and then Reader_Count /= 1)
              or (Has_Event'Length = 0 and then Reader_Count < 1)
            then
               Mucfgcheck.Validation_Errors.Insert
                 (Msg => "Invalid number of "
                  & "readers for channel '" & Channel_Name & "':"
                  & Reader_Count'Img);
            end if;

            if Writer_Count /= 1 then
               Mucfgcheck.Validation_Errors.Insert
                 (Msg => "Invalid number of "
                  & "writers for channel '" & Channel_Name & "':"
                  & Writer_Count'Img);
            end if;
         end;
      end loop;
   end Channel_Reader_Writer;

   -------------------------------------------------------------------------

   procedure Channel_Writer_Has_Event_ID (XML_Data : Muxml.XML_Data_Type)
   is
   begin
      Check_Channel_Endpoint_Events_Attr
        (XML_Data  => XML_Data,
         XPath     => "/system/channels/channel[@hasEvent]",
         Endpoint  => "writer",
         Attr_Name => "event");
      Check_Channel_Has_Event_Attr
        (XML_Data  => XML_Data,
         Endpoint  => "writer",
         Attr_Name => "event");
   end Channel_Writer_Has_Event_ID;

   -------------------------------------------------------------------------

   procedure Check_Attribute_Uniqueness
     (Nodes       : DOM.Core.Node_List;
      Attr_Name   : String;
      Description : String)
   is
      --  Check inequality of desired node attributes.
      procedure Check_Inequality (Left, Right : DOM.Core.Node);

      ----------------------------------------------------------------------

      procedure Check_Inequality (Left, Right : DOM.Core.Node)
      is
         Left_Attr  : constant String := DOM.Core.Elements.Get_Attribute
           (Elem => Left,
            Name => Attr_Name);
         Right_Attr : constant String := DOM.Core.Elements.Get_Attribute
           (Elem => Right,
            Name => Attr_Name);
      begin
         if Left_Attr = Right_Attr then
            Mucfgcheck.Validation_Errors.Insert
              (Msg => Mutools.Utils.Capitalize
                 (Description) & " " & Attr_Name & " '" & Left_Attr
               & "' is not unique");
         end if;
      end Check_Inequality;
   begin
      Mulog.Log (Msg => "Checking uniqueness of" & DOM.Core.Nodes.Length
                 (List => Nodes)'Img & " " & Description & " "
                 & Attr_Name & "(s)");
      Mucfgcheck.Compare_All (Nodes      => Nodes,
                              Comparator => Check_Inequality'Access);
   end Check_Attribute_Uniqueness;

   -------------------------------------------------------------------------

   procedure Check_Channel_Endpoint_Events_Attr
     (XML_Data  : Muxml.XML_Data_Type;
      XPath     : String;
      Endpoint  : String;
      Attr_Name : String)
   is
      Channels  : constant DOM.Core.Node_List
        := McKae.XML.XPath.XIA.XPath_Query
          (N     => XML_Data.Doc,
           XPath => XPath);
      Endpoints : constant DOM.Core.Node_List
        := McKae.XML.XPath.XIA.XPath_Query
          (N     => XML_Data.Doc,
           XPath => "/system/subjects/subject/channels/" & Endpoint);
   begin
      Mulog.Log (Msg => "Checking '" & Attr_Name & "' attribute of"
                 & DOM.Core.Nodes.Length (List => Channels)'Img & " channel "
                 & Endpoint & "(s) with associated event");

      for I in 0 .. DOM.Core.Nodes.Length (List => Channels) - 1 loop
         declare
            Channel_Node : constant DOM.Core.Node
              := DOM.Core.Nodes.Item
                (List  => Channels,
                 Index => I);
            Channel_Name : constant String
              := DOM.Core.Elements.Get_Attribute
                (Elem => Channel_Node,
                 Name => "name");
            Node         : constant DOM.Core.Node
              := Muxml.Utils.Get_Element
                (Nodes     => Endpoints,
                 Ref_Attr  => "physical",
                 Ref_Value => Channel_Name);
         begin
            if DOM.Core.Elements.Get_Attribute
              (Elem => Node,
               Name => Attr_Name) = ""
            then
               Mucfgcheck.Validation_Errors.Insert
                 (Msg => "Missing '" & Attr_Name & "' attribute for "
                  & Endpoint & " of channel '" & Channel_Name & "'");
            end if;
         end;
      end loop;
   end Check_Channel_Endpoint_Events_Attr;

   -------------------------------------------------------------------------

   procedure Check_Channel_Has_Event_Attr
     (XML_Data  : Muxml.XML_Data_Type;
      Endpoint  : String;
      Attr_Name : String)
   is
      use type DOM.Core.Node;

      Channels  : constant DOM.Core.Node_List
        := McKae.XML.XPath.XIA.XPath_Query
          (N     => XML_Data.Doc,
           XPath => "/system/channels/channel[@hasEvent]");
      Endpoints : constant DOM.Core.Node_List
        := McKae.XML.XPath.XIA.XPath_Query
          (N     => XML_Data.Doc,
           XPath => "/system/subjects/subject/channels/" & Endpoint
           & "[@" & Attr_Name & "]");
   begin
      Mulog.Log (Msg => "Checking 'hasEvent' attribute of"
                 & DOM.Core.Nodes.Length (List => Endpoints)'Img
                 & " " & Endpoint & "(s) with associated event");

      for I in 0 .. DOM.Core.Nodes.Length (List => Endpoints) - 1 loop
         declare
            Node : constant DOM.Core.Node
              := DOM.Core.Nodes.Item
                (List  => Endpoints,
                 Index => I);
            Logical : constant String
              := DOM.Core.Elements.Get_Attribute
                (Elem => Node,
                 Name => "logical");
            Physical : constant String
              := DOM.Core.Elements.Get_Attribute
                (Elem => Node,
                 Name => "physical");
            Channel : constant DOM.Core.Node
              := Muxml.Utils.Get_Element
                (Nodes     => Channels,
                 Ref_Attr  => "name",
                 Ref_Value => Physical);
         begin
            if Channel = null then
               Mucfgcheck.Validation_Errors.Insert
                 (Msg => "Logical channel " & Endpoint & " '" & Logical
                  & "' specifies event but referenced channel '" & Physical
                  & "' is missing hasEvent attribute");
            end if;
         end;
      end loop;
   end Check_Channel_Has_Event_Attr;

   -------------------------------------------------------------------------

   procedure Check_Component_Resource_Mappings
     (Logical_Resources  : DOM.Core.Node_List;
      Physical_Resources : DOM.Core.Node_List;
      Resource_Type      : String;
      Subject            : DOM.Core.Node;
      Additional_Check   : not null access procedure
        (Logical_Resource  : DOM.Core.Node;
         Physical_Resource : DOM.Core.Node;
         Mapping           : DOM.Core.Node) := No_Check'Access)

   is
      Subj_Name     : constant String
        := DOM.Core.Elements.Get_Attribute
          (Elem => Subject,
           Name => "name");
      Comp_Name     : constant String
        := Muxml.Utils.Get_Attribute
          (Doc   => Subject,
           XPath => "component",
           Name  => "ref");
      Mappings      : constant DOM.Core.Node_List
        := McKae.XML.XPath.XIA.XPath_Query
          (N     => Subject,
           XPath => "component/map");
      Log_Res_Count : constant Natural
        := DOM.Core.Nodes.Length (List => Logical_Resources);
   begin
      if Log_Res_Count = 0 then
         return;
      end if;

      Mulog.Log (Msg => "Checking mapping(s) of" & Log_Res_Count'Img
                 & " component logical " & Resource_Type & " resource(s) of "
                 & "subject '" & Subj_Name & "' with component '" & Comp_Name
                 & "'");
      for I in 0 .. Log_Res_Count - 1 loop
         declare
            use type DOM.Core.Node;

            Log_Res  : constant DOM.Core.Node
              := DOM.Core.Nodes.Item
                (List  => Logical_Resources,
                 Index => I);
            Log_Name : constant String
              := DOM.Core.Elements.Get_Attribute
                (Elem => Log_Res,
                 Name => "logical");
            Mapping  : constant DOM.Core.Node
              := Muxml.Utils.Get_Element
                (Nodes     => Mappings,
                 Ref_Attr  => "logical",
                 Ref_Value => Log_Name);
         begin
            if Mapping = null then
               Mucfgcheck.Validation_Errors.Insert
                 (Msg => "Subject '" & Subj_Name
                  & "' does not map logical " & Resource_Type & " '" & Log_Name
                  & "' as requested by referenced component '" & Comp_Name
                  & "'");
               return;
            end if;

            declare
               Phys_Name : constant String
                 := DOM.Core.Elements.Get_Attribute
                   (Elem => Mapping,
                    Name => "physical");
               Phys_Res  : constant DOM.Core.Node
                 := Muxml.Utils.Get_Element
                   (Nodes     => Physical_Resources,
                    Ref_Attr  => "name",
                    Ref_Value => Phys_Name);
            begin
               if Phys_Res = null then
                  Mucfgcheck.Validation_Errors.Insert
                    (Msg => "Physical "
                     & Resource_Type & " '" & Phys_Name & "' referenced by "
                     & "mapping of component logical resource '" & Log_Name
                     & "' by subject" & " '" & Subj_Name & "' does not exist");
                  return;
               end if;

               Additional_Check (Logical_Resource  => Log_Res,
                                 Physical_Resource => Phys_Res,
                                 Mapping           => Mapping);
            end;
         end;
      end loop;
   end Check_Component_Resource_Mappings;

   -------------------------------------------------------------------------

   procedure Check_Component_Resources
     (Logical_Resources  : DOM.Core.Node_List;
      Physical_Resources : DOM.Core.Node_List;
      Subject            : DOM.Core.Node;
      Check_Resource     : not null access procedure
        (Logical_Resource  : DOM.Core.Node;
         Physical_Resource : DOM.Core.Node))
   is
      Mappings      : constant DOM.Core.Node_List
        := McKae.XML.XPath.XIA.XPath_Query
          (N     => Subject,
           XPath => "component/map");
      Log_Res_Count : constant Natural
        := DOM.Core.Nodes.Length (List => Logical_Resources);
   begin
      for I in 0 .. Log_Res_Count - 1 loop
         declare
            use type DOM.Core.Node;

            Log_Res   : constant DOM.Core.Node
              := DOM.Core.Nodes.Item
                (List  => Logical_Resources,
                 Index => I);
            Log_Name  : constant String
              := DOM.Core.Elements.Get_Attribute
                (Elem => Log_Res,
                 Name => "logical");
            Phys_Name : constant String
              := Muxml.Utils.Get_Attribute
                (Nodes     => Mappings,
                 Ref_Attr  => "logical",
                 Ref_Value => Log_Name,
                 Attr_Name => "physical");
            Phys_Res  : constant DOM.Core.Node
              := Muxml.Utils.Get_Element
                (Nodes     => Physical_Resources,
                 Ref_Attr  => "name",
                 Ref_Value => Phys_Name);
         begin
            Check_Resource (Logical_Resource  => Log_Res,
                            Physical_Resource => Phys_Res);
         end;
      end loop;
   end Check_Component_Resources;

   -------------------------------------------------------------------------

   procedure Check_Subject_Resource_Maps_Attr_Uniqueness
     (XML_Data : Muxml.XML_Data_Type;
      Attr     : String)
   is
      --  Check inequality of specified mappings attribute.
      procedure Check_Inequality (Left, Right : DOM.Core.Node);

      ----------------------------------------------------------------------

      procedure Check_Inequality (Left, Right : DOM.Core.Node)
      is
         Left_Name  : constant String := DOM.Core.Elements.Get_Attribute
           (Elem => Left,
            Name => Attr);
         Right_Name : constant String := DOM.Core.Elements.Get_Attribute
           (Elem => Right,
            Name => Attr);
      begin
         if Left_Name = Right_Name then
            Mucfgcheck.Validation_Errors.Insert
              (Msg => "Multiple " & Attr
               & " resource mappings with name '" & Left_Name
               & "' in subject '"
               & DOM.Core.Elements.Get_Attribute
                 (Elem => Muxml.Utils.Ancestor_Node
                      (Node  => Left,
                       Level => 2),
                  Name => "name") & "'");
         end if;
      end Check_Inequality;

      Subjects : constant DOM.Core.Node_List
        := McKae.XML.XPath.XIA.XPath_Query
          (N     => XML_Data.Doc,
           XPath => "/system/subjects/subject");
   begin
      for I in 0 .. DOM.Core.Nodes.Length (List => Subjects) - 1 loop
         declare
            Subj_Node : constant DOM.Core.Node
              := DOM.Core.Nodes.Item (List  => Subjects,
                                      Index => I);
            Mappings  : constant DOM.Core.Node_List
              := McKae.XML.XPath.XIA.XPath_Query
                (N     => Subj_Node,
                 XPath => "component/map");
         begin
            if DOM.Core.Nodes.Length (List => Mappings) > 1 then
               Mulog.Log (Msg => "Checking uniqueness of"
                          & DOM.Core.Nodes.Length (List => Mappings)'Img
                          & " subject " & Attr & " resource mappings");
               Mucfgcheck.Compare_All (Nodes      => Mappings,
                                       Comparator => Check_Inequality'Access);
            end if;
         end;
      end loop;
   end Check_Subject_Resource_Maps_Attr_Uniqueness;

   -------------------------------------------------------------------------

   procedure Component_Channel_Event (XML_Data : Muxml.XML_Data_Type)
   is
      Components    : constant DOM.Core.Node_List
        := McKae.XML.XPath.XIA.XPath_Query
          (N     => XML_Data.Doc,
           XPath => "/system/components/component");
      Phys_Channels : constant DOM.Core.Node_List
        := McKae.XML.XPath.XIA.XPath_Query
          (N     => XML_Data.Doc,
           XPath => "/system/channels/channel");
      Subjects      : constant DOM.Core.Node_List
        := McKae.XML.XPath.XIA.XPath_Query
          (N     => XML_Data.Doc,
           XPath => "/system/subjects/subject[component]");
   begin
      for I in 0 .. DOM.Core.Nodes.Length (List => Subjects) - 1 loop
         declare
            Subj_Node     : constant DOM.Core.Node
              := DOM.Core.Nodes.Item
                (List  => Subjects,
                 Index => I);
            Subj_Name     : constant String
              := DOM.Core.Elements.Get_Attribute
                (Elem => Subj_Node,
                 Name => "name");
            Comp_Name     : constant String
              := Muxml.Utils.Get_Attribute
                (Doc   => Subj_Node,
                 XPath => "component",
                 Name  => "ref");
            Comp_Node     : constant DOM.Core.Node
              := Muxml.Utils.Get_Element
                (Nodes     => Components,
                 Ref_Attr  => "name",
                 Ref_Value => Comp_Name);
            Comp_Channels : constant DOM.Core.Node_List
              := McKae.XML.XPath.XIA.XPath_Query
                (N     => Comp_Node,
                 XPath => "requires/channels/*[self::reader or self::writer]");
            Channel_Count : constant Natural
              := DOM.Core.Nodes.Length (Comp_Channels);

            --  Check equality of logical and physical channel event.
            procedure Check_Channel_Event
              (Logical_Resource  : DOM.Core.Node;
               Physical_Resource : DOM.Core.Node);

            ----------------------------------------------------------------

            procedure Check_Channel_Event
              (Logical_Resource  : DOM.Core.Node;
               Physical_Resource : DOM.Core.Node)
            is
               Log_Has_Event : constant Boolean
                 := DOM.Core.Elements.Get_Attribute (Elem => Logical_Resource,
                                                     Name => "event") /= ""
                 or DOM.Core.Elements.Get_Attribute (Elem => Logical_Resource,
                                                     Name => "vector") /= "";
               Log_Channel_Name : constant String
                 := DOM.Core.Elements.Get_Attribute
                   (Elem => Logical_Resource,
                    Name => "logical");
               Phys_Has_Event : constant Boolean
                 := DOM.Core.Elements.Get_Attribute
                   (Elem => Physical_Resource,
                    Name => "hasEvent") /= "";
               Phys_Channel_Name : constant String
                 := DOM.Core.Elements.Get_Attribute
                   (Elem => Physical_Resource,
                    Name => "name");
            begin
               if Log_Has_Event and then not Phys_Has_Event then
                  Mucfgcheck.Validation_Errors.Insert
                    (Msg   => "Component '"
                     & Comp_Name & "' referenced by subject '" & Subj_Name
                     & "' requests logical channel '" & Log_Channel_Name
                     & "' with" & (if Log_Has_Event then "" else "out")
                     & " event but mapped physical channel '"
                     & Phys_Channel_Name & "' has"
                     & (if Phys_Has_Event then "" else " no") & " event");
               end if;
            end Check_Channel_Event;
         begin
            if Channel_Count > 0 then
               Mulog.Log (Msg => "Checking events of" & Channel_Count'Img
                          & " component '" & Comp_Name & "' channel(s) "
                          & "referenced by subject '" & Subj_Name & "'");

               Check_Component_Resources
                 (Logical_Resources  => Comp_Channels,
                  Physical_Resources => Phys_Channels,
                  Subject            => Subj_Node,
                  Check_Resource     => Check_Channel_Event'Access);
            end if;
         end;
      end loop;
   end Component_Channel_Event;

   -------------------------------------------------------------------------

   procedure Component_Channel_Name_Uniqueness
     (XML_Data : Muxml.XML_Data_Type)
   is
      use Ada.Strings.Unbounded;

      Components : constant DOM.Core.Node_List
        := McKae.XML.XPath.XIA.XPath_Query
          (N     => XML_Data.Doc,
           XPath => "/system/components/component");

      Component_Name : Unbounded_String;

      --  Check inequality of logical channel names.
      procedure Check_Inequality (Left, Right : DOM.Core.Node);

      ----------------------------------------------------------------------

      procedure Check_Inequality (Left, Right : DOM.Core.Node)
      is
         Left_Name  : constant String := DOM.Core.Elements.Get_Attribute
           (Elem => Left,
            Name => "logical");
         Right_Name : constant String := DOM.Core.Elements.Get_Attribute
           (Elem => Right,
            Name => "logical");
      begin
         if Left_Name = Right_Name then
            Mucfgcheck.Validation_Errors.Insert
              (Msg => "Multiple channels with "
               & "name '" & Left_Name & "' in component '"
               & To_String (Component_Name) & "'");
         end if;
      end Check_Inequality;
   begin
      for I in 0 .. DOM.Core.Nodes.Length (List => Components) - 1 loop
         declare
            Comp_Node : constant DOM.Core.Node
              := DOM.Core.Nodes.Item (List  => Components,
                                      Index => I);
            Channels  : constant DOM.Core.Node_List
              := McKae.XML.XPath.XIA.XPath_Query
                (N     => Comp_Node,
                 XPath => "requires/channels/*");
         begin
            Component_Name := To_Unbounded_String
              (DOM.Core.Elements.Get_Attribute
                 (Elem => Comp_Node,
                  Name => "name"));
            if DOM.Core.Nodes.Length (List => Channels) > 1 then
               Mulog.Log (Msg => "Checking uniqueness of"
                          & DOM.Core.Nodes.Length (List => Channels)'Img
                          & " channel names in component '"
                          & To_String (Component_Name) & "'");
               Mucfgcheck.Compare_All (Nodes      => Channels,
                                       Comparator => Check_Inequality'Access);
            end if;
         end;
      end loop;
   end Component_Channel_Name_Uniqueness;

   -------------------------------------------------------------------------

   procedure Component_Channel_Size (XML_Data : Muxml.XML_Data_Type)
   is
      Components    : constant DOM.Core.Node_List
        := McKae.XML.XPath.XIA.XPath_Query
          (N     => XML_Data.Doc,
           XPath => "/system/components/component");
      Phys_Channels : constant DOM.Core.Node_List
        := McKae.XML.XPath.XIA.XPath_Query
          (N     => XML_Data.Doc,
           XPath => "/system/channels/channel");
      Subjects      : constant DOM.Core.Node_List
        := McKae.XML.XPath.XIA.XPath_Query
          (N     => XML_Data.Doc,
           XPath => "/system/subjects/subject[component]");
   begin
      for I in 0 .. DOM.Core.Nodes.Length (List => Subjects) - 1 loop
         declare
            Subj_Node     : constant DOM.Core.Node
              := DOM.Core.Nodes.Item
                (List  => Subjects,
                 Index => I);
            Subj_Name     : constant String
              := DOM.Core.Elements.Get_Attribute
                (Elem => Subj_Node,
                 Name => "name");
            Comp_Name     : constant String
              := Muxml.Utils.Get_Attribute
                (Doc   => Subj_Node,
                 XPath => "component",
                 Name  => "ref");
            Comp_Node     : constant DOM.Core.Node
              := Muxml.Utils.Get_Element
                (Nodes     => Components,
                 Ref_Attr  => "name",
                 Ref_Value => Comp_Name);
            Comp_Channels : constant DOM.Core.Node_List
              := McKae.XML.XPath.XIA.XPath_Query
                (N     => Comp_Node,
                 XPath => "requires/channels/*[self::reader or self::writer]");
            Channel_Count : constant Natural
              := DOM.Core.Nodes.Length (Comp_Channels);

            --  Check equality of logical and physical channel size.
            procedure Check_Channel_Size
              (Logical_Resource  : DOM.Core.Node;
               Physical_Resource : DOM.Core.Node);

            ----------------------------------------------------------------

            procedure Check_Channel_Size
              (Logical_Resource  : DOM.Core.Node;
               Physical_Resource : DOM.Core.Node)
            is
               use type Interfaces.Unsigned_64;

               Log_Channel_Name : constant String
                 := DOM.Core.Elements.Get_Attribute
                   (Elem => Logical_Resource,
                    Name => "logical");
               Log_Channel_Size : constant String
                 := DOM.Core.Elements.Get_Attribute
                   (Elem => Logical_Resource,
                    Name => "size");
               Phys_Channel_Size : constant String
                 := DOM.Core.Elements.Get_Attribute
                   (Elem => Physical_Resource,
                    Name => "size");
               Phys_Channel_Name : constant String
                 := DOM.Core.Elements.Get_Attribute
                   (Elem => Physical_Resource,
                    Name => "name");
            begin
               if Interfaces.Unsigned_64'Value (Log_Channel_Size)
                 /= Interfaces.Unsigned_64'Value (Phys_Channel_Size)
               then
                  Mucfgcheck.Validation_Errors.Insert
                    (Msg => "Component '"
                     & Comp_Name & "' referenced by subject '" & Subj_Name
                     & "' requests size " & Log_Channel_Size & " for "
                     & "logical channel '" & Log_Channel_Name & "' but "
                     & "linked physical channel '" & Phys_Channel_Name
                     & "' " & "has size " & Phys_Channel_Size);
               end if;
            end Check_Channel_Size;
         begin
            if Channel_Count > 0 then
               Mulog.Log (Msg => "Checking size of" & Channel_Count'Img
                          & " component '" & Comp_Name & "' channel(s) "
                          & "referenced by subject '" & Subj_Name & "'");

               Check_Component_Resources
                 (Logical_Resources  => Comp_Channels,
                  Physical_Resources => Phys_Channels,
                  Subject            => Subj_Node,
                  Check_Resource     => Check_Channel_Size'Access);
            end if;
         end;
      end loop;
   end Component_Channel_Size;

   -------------------------------------------------------------------------

   procedure Component_Device_IO_Port_Range (XML_Data : Muxml.XML_Data_Type)
   is
      Components   : constant DOM.Core.Node_List
        := McKae.XML.XPath.XIA.XPath_Query
          (N     => XML_Data.Doc,
           XPath => "/system/components/component");
      Phys_Devices : constant DOM.Core.Node_List
        := McKae.XML.XPath.XIA.XPath_Query
          (N     => XML_Data.Doc,
           XPath => "/system/hardware/devices/device");
      Subjects     : constant DOM.Core.Node_List
        := McKae.XML.XPath.XIA.XPath_Query
          (N     => XML_Data.Doc,
           XPath => "/system/subjects/subject[component]");
   begin
      for I in 0 .. DOM.Core.Nodes.Length (List => Subjects) - 1 loop
         declare
            Subj_Node    : constant DOM.Core.Node
              := DOM.Core.Nodes.Item
                (List  => Subjects,
                 Index => I);
            Subj_Name    : constant String
              := DOM.Core.Elements.Get_Attribute
                (Elem => Subj_Node,
                 Name => "name");
            Comp_Name    : constant String
              := Muxml.Utils.Get_Attribute
                (Doc   => Subj_Node,
                 XPath => "component",
                 Name  => "ref");
            Comp_Node    : constant DOM.Core.Node
              := Muxml.Utils.Get_Element
                (Nodes     => Components,
                 Ref_Attr  => "name",
                 Ref_Value => Comp_Name);
            Comp_Devices : constant DOM.Core.Node_List
              := McKae.XML.XPath.XIA.XPath_Query
                (N     => Comp_Node,
                 XPath => "requires/devices/device");
            Dev_Count    : constant Natural
              := DOM.Core.Nodes.Length (Comp_Devices);

            --  Check equality of logical and physical device I/O port range.
            procedure Check_Dev_IO_Port_Range
              (Logical_Dev  : DOM.Core.Node;
               Physical_Dev : DOM.Core.Node);

            ----------------------------------------------------------------

            procedure Check_Dev_IO_Port_Range
              (Logical_Dev  : DOM.Core.Node;
               Physical_Dev : DOM.Core.Node)
            is
               Log_Dev_Name   : constant String
                 := DOM.Core.Elements.Get_Attribute
                   (Elem => Logical_Dev,
                    Name => "logical");
               Log_Dev_Ports  : constant DOM.Core.Node_List
                 := McKae.XML.XPath.XIA.XPath_Query
                   (N     => Logical_Dev,
                    XPath => "ioPort");
               Phys_Dev_Ports : constant DOM.Core.Node_List
                 := McKae.XML.XPath.XIA.XPath_Query
                   (N     => Physical_Dev,
                    XPath => "ioPort");
               Phys_Dev_Name  : constant String
                 := DOM.Core.Elements.Get_Attribute
                   (Elem => Physical_Dev,
                    Name => "name");
               Mappings       : constant DOM.Core.Node_List
                 := McKae.XML.XPath.XIA.XPath_Query
                   (N     => Subj_Node,
                    XPath => "component/map[@logical='" & Log_Dev_Name
                    & "']/map");
            begin
               for I in 0 .. DOM.Core.Nodes.Length (List => Log_Dev_Ports) - 1
               loop
                  declare
                     use type Interfaces.Unsigned_64;

                     Log_Dev_Port        : constant DOM.Core.Node
                       := DOM.Core.Nodes.Item
                         (List  => Log_Dev_Ports,
                          Index => I);
                     Log_Dev_Port_Name   : constant String
                       := DOM.Core.Elements.Get_Attribute
                         (Elem => Log_Dev_Port,
                          Name => "logical");
                     Log_Dev_Port_Start  : constant String
                       := DOM.Core.Elements.Get_Attribute
                         (Elem => Log_Dev_Port,
                          Name => "start");
                     Log_Dev_Port_End    : constant String
                       := DOM.Core.Elements.Get_Attribute
                         (Elem => Log_Dev_Port,
                          Name => "end");
                     Phys_Dev_Port_Name  : constant String
                       := Muxml.Utils.Get_Attribute
                         (Nodes     => Mappings,
                          Ref_Attr  => "logical",
                          Ref_Value => Log_Dev_Port_Name,
                          Attr_Name => "physical");
                     Phys_Dev_Port       : constant DOM.Core.Node
                       := Muxml.Utils.Get_Element
                         (Nodes     => Phys_Dev_Ports,
                          Ref_Attr  => "name",
                          Ref_Value => Phys_Dev_Port_Name);
                     Phys_Dev_Port_Start : constant String
                       := DOM.Core.Elements.Get_Attribute
                         (Elem => Phys_Dev_Port,
                          Name => "start");
                     Phys_Dev_Port_End   : constant String
                       := DOM.Core.Elements.Get_Attribute
                         (Elem => Phys_Dev_Port,
                          Name => "end");
                  begin
                     if Interfaces.Unsigned_64'Value (Log_Dev_Port_Start)
                       /= Interfaces.Unsigned_64'Value (Phys_Dev_Port_Start)
                       or Interfaces.Unsigned_64'Value (Log_Dev_Port_End)
                       /= Interfaces.Unsigned_64'Value (Phys_Dev_Port_End)
                     then
                        Mucfgcheck.Validation_Errors.Insert
                          (Msg => "Component '"
                           & Comp_Name & "' referenced by subject '"
                           & Subj_Name & "' requests I/O range "
                           & Log_Dev_Port_Start & ".." & Log_Dev_Port_End
                           & " for '" & Log_Dev_Name & "->"
                           & Log_Dev_Port_Name & "' but physical device '"
                           & Phys_Dev_Name & "->" & Phys_Dev_Port_Name & "' "
                           & "has " & Phys_Dev_Port_Start & ".."
                           & Phys_Dev_Port_End);
                     end if;
                  end;
               end loop;
            end Check_Dev_IO_Port_Range;
         begin
            if Dev_Count > 0 then
               Mulog.Log (Msg => "Checking I/O port ranges of" & Dev_Count'Img
                          & " component '" & Comp_Name & "' device(s) "
                          & "referenced by subject '" & Subj_Name & "'");

               Check_Component_Resources
                 (Logical_Resources  => Comp_Devices,
                  Physical_Resources => Phys_Devices,
                  Subject            => Subj_Node,
                  Check_Resource     => Check_Dev_IO_Port_Range'Access);
            end if;
         end;
      end loop;
   end Component_Device_IO_Port_Range;

   -------------------------------------------------------------------------

   procedure Component_Device_Memory_Size (XML_Data : Muxml.XML_Data_Type)
   is
      Components   : constant DOM.Core.Node_List
        := McKae.XML.XPath.XIA.XPath_Query
          (N     => XML_Data.Doc,
           XPath => "/system/components/component");
      Phys_Devices : constant DOM.Core.Node_List
        := McKae.XML.XPath.XIA.XPath_Query
          (N     => XML_Data.Doc,
           XPath => "/system/hardware/devices/device");
      Subjects     : constant DOM.Core.Node_List
        := McKae.XML.XPath.XIA.XPath_Query
          (N     => XML_Data.Doc,
           XPath => "/system/subjects/subject[component]");
   begin
      for I in 0 .. DOM.Core.Nodes.Length (List => Subjects) - 1 loop
         declare
            Subj_Node    : constant DOM.Core.Node
              := DOM.Core.Nodes.Item
                (List  => Subjects,
                 Index => I);
            Subj_Name    : constant String
              := DOM.Core.Elements.Get_Attribute
                (Elem => Subj_Node,
                 Name => "name");
            Comp_Name    : constant String
              := Muxml.Utils.Get_Attribute
                (Doc   => Subj_Node,
                 XPath => "component",
                 Name  => "ref");
            Comp_Node    : constant DOM.Core.Node
              := Muxml.Utils.Get_Element
                (Nodes     => Components,
                 Ref_Attr  => "name",
                 Ref_Value => Comp_Name);
            Comp_Devices : constant DOM.Core.Node_List
              := McKae.XML.XPath.XIA.XPath_Query
                (N     => Comp_Node,
                 XPath => "requires/devices/device");
            Dev_Count    : constant Natural
              := DOM.Core.Nodes.Length (Comp_Devices);

            --  Check equality of logical and physical device memory size.
            procedure Check_Dev_Mem_Size
              (Logical_Dev  : DOM.Core.Node;
               Physical_Dev : DOM.Core.Node);

            ----------------------------------------------------------------

            procedure Check_Dev_Mem_Size
              (Logical_Dev  : DOM.Core.Node;
               Physical_Dev : DOM.Core.Node)
            is
               Log_Dev_Name  : constant String
                 := DOM.Core.Elements.Get_Attribute
                   (Elem => Logical_Dev,
                    Name => "logical");
               Log_Dev_Mem   : constant DOM.Core.Node_List
                 := McKae.XML.XPath.XIA.XPath_Query
                   (N     => Logical_Dev,
                    XPath => "memory");
               Phys_Dev_Mem  : constant DOM.Core.Node_List
                 := McKae.XML.XPath.XIA.XPath_Query
                   (N     => Physical_Dev,
                    XPath => "memory");
               Phys_Dev_Name : constant String
                 := DOM.Core.Elements.Get_Attribute
                   (Elem => Physical_Dev,
                    Name => "name");
               Mappings      : constant DOM.Core.Node_List
                 := McKae.XML.XPath.XIA.XPath_Query
                   (N     => Subj_Node,
                    XPath => "component/map[@logical='" & Log_Dev_Name
                    & "']/map");
            begin
               for I in 0 .. DOM.Core.Nodes.Length (List => Log_Dev_Mem) - 1
               loop
                  declare
                     use type Interfaces.Unsigned_64;

                     Log_Dev_Memory    : constant DOM.Core.Node
                       := DOM.Core.Nodes.Item
                         (List  => Log_Dev_Mem,
                          Index => I);
                     Log_Dev_Mem_Name  : constant String
                       := DOM.Core.Elements.Get_Attribute
                         (Elem => Log_Dev_Memory,
                          Name => "logical");
                     Log_Dev_Mem_Size  : constant String
                       := DOM.Core.Elements.Get_Attribute
                         (Elem => Log_Dev_Memory,
                          Name => "size");
                     Phys_Dev_Mem_Name : constant String
                       := Muxml.Utils.Get_Attribute
                         (Nodes     => Mappings,
                          Ref_Attr  => "logical",
                          Ref_Value => Log_Dev_Mem_Name,
                          Attr_Name => "physical");
                     Phys_Dev_Mem_Size : constant String
                       := Muxml.Utils.Get_Attribute
                         (Nodes     => Phys_Dev_Mem,
                          Ref_Attr  => "name",
                          Ref_Value => Phys_Dev_Mem_Name,
                          Attr_Name => "size");
                  begin
                     if Interfaces.Unsigned_64'Value (Log_Dev_Mem_Size)
                       /= Interfaces.Unsigned_64'Value (Phys_Dev_Mem_Size)
                     then
                        Mucfgcheck.Validation_Errors.Insert
                          (Msg => "Component '"
                           & Comp_Name & "' referenced by subject '"
                           & Subj_Name & "' requests size " & Log_Dev_Mem_Size
                           & " for " & "logical device memory '" & Log_Dev_Name
                           & "->" & Log_Dev_Mem_Name & "' but linked physical "
                           & "device memory '" & Phys_Dev_Name & "->"
                           & Phys_Dev_Mem_Name & "' " & "has size "
                           & Phys_Dev_Mem_Size);
                     end if;
                  end;
               end loop;
            end Check_Dev_Mem_Size;
         begin
            if Dev_Count > 0 then
               Mulog.Log (Msg => "Checking memory size of" & Dev_Count'Img
                          & " component '" & Comp_Name & "' device(s) "
                          & "referenced by subject '" & Subj_Name & "'");

               Check_Component_Resources
                 (Logical_Resources  => Comp_Devices,
                  Physical_Resources => Phys_Devices,
                  Subject            => Subj_Node,
                  Check_Resource     => Check_Dev_Mem_Size'Access);
            end if;
         end;
      end loop;
   end Component_Device_Memory_Size;

   -------------------------------------------------------------------------

   procedure Component_Library_Cyclic_References
     (XML_Data : Muxml.XML_Data_Type)
   is
      use Ada.Strings.Unbounded;

      Libraries  : constant DOM.Core.Node_List
        := McKae.XML.XPath.XIA.XPath_Query
          (N     => XML_Data.Doc,
           XPath => "/system/components/library");
      Components : constant DOM.Core.Node_List
        := McKae.XML.XPath.XIA.XPath_Query
          (N     => XML_Data.Doc,
           XPath => "/system/components/*[depends/library]");

      Count : constant Natural := DOM.Core.Nodes.Length (List => Components);

      package SOCN is new Ada.Containers.Hashed_Sets
        (Element_Type        => Unbounded_String,
         Hash                => Ada.Strings.Unbounded.Hash,
         Equivalent_Elements => Ada.Strings.Unbounded."=");

      Active_Nodes : SOCN.Set;

      --  Recursively resolve dependencies of given component/library node.
      procedure Resolve_Depends (Node : DOM.Core.Node);

      ----------------------------------------------------------------------

      procedure Resolve_Depends (Node : DOM.Core.Node)
      is
         use type DOM.Core.Node;

         function U
           (Source : String)
            return Unbounded_String
            renames To_Unbounded_String;

         Name : constant String
           := DOM.Core.Elements.Get_Attribute (Elem => Node,
                                               Name => "name");
         Deps_Node : constant DOM.Core.Node
           := Muxml.Utils.Get_Element (Doc   => Node,
                                       XPath => "depends");
         Deps : DOM.Core.Node_List;
      begin
         if Deps_Node = null then
            return;
         end if;

         if Active_Nodes.Contains (Item => U (Source => Name)) then
            raise Mucfgcheck.Validation_Errors.Validation_Error with Name;
         end if;

         Active_Nodes.Insert (New_Item => U (Source => Name));
         Deps := McKae.XML.XPath.XIA.XPath_Query
             (N     => Deps_Node,
              XPath => "library");

         for I in 0 .. DOM.Core.Nodes.Length (List => Deps) - 1 loop
            declare
               Cur_Dep  : constant DOM.Core.Node
                 := DOM.Core.Nodes.Item (List  => Deps,
                                         Index => I);
               Dep_Name : constant String
                 := DOM.Core.Elements.Get_Attribute (Elem => Cur_Dep,
                                                     Name => "ref");
               Lib_Node : constant DOM.Core.Node
                 := Muxml.Utils.Get_Element (Nodes     => Libraries,
                                             Ref_Attr  => "name",
                                             Ref_Value => Dep_Name);
            begin
               Resolve_Depends (Node => Lib_Node);

            exception
               when E : Mucfgcheck.Validation_Errors.Validation_Error =>
                  raise Mucfgcheck.Validation_Errors.Validation_Error
                    with Name & "->" &
                    Ada.Exceptions.Exception_Message (X => E);
            end;
         end loop;
         Active_Nodes.Delete (Item => U (Source => Name));
      end Resolve_Depends;
   begin
      Mulog.Log (Msg => "Checking cyclic dependencies of " & Count'Img
                 & " component(s)");

      for I in 0 .. DOM.Core.Nodes.Length (List => Components) - 1 loop
         declare
            Comp_Node : constant DOM.Core.Node
              := DOM.Core.Nodes.Item
                (List  => Components,
                 Index => I);
         begin
            Resolve_Depends (Node => Comp_Node);
         end;
      end loop;

   exception
      when E : Mucfgcheck.Validation_Errors.Validation_Error =>
         Mucfgcheck.Validation_Errors.Insert
           (Msg => "Cyclic component dependency detected: "
            & Ada.Exceptions.Exception_Message (X => E));
   end Component_Library_Cyclic_References;

   -------------------------------------------------------------------------

   procedure Component_Library_References (XML_Data : Muxml.XML_Data_Type)
   is
      --  Returns the error message for a given reference node.
      procedure Error_Msg
        (Node    :     DOM.Core.Node;
         Err_Str : out Ada.Strings.Unbounded.Unbounded_String;
         Fatal   : out Boolean);

      ----------------------------------------------------------------------

      procedure Error_Msg
        (Node    :     DOM.Core.Node;
         Err_Str : out Ada.Strings.Unbounded.Unbounded_String;
         Fatal   : out Boolean)
      is
         Ref_Name  : constant String := DOM.Core.Elements.Get_Attribute
           (Elem => Node,
            Name => "ref");
         Comp_Name : constant String := DOM.Core.Elements.Get_Attribute
           (Elem => Muxml.Utils.Ancestor_Node
              (Node  => Node,
               Level => 2),
            Name => "name");
      begin
         Err_Str := Ada.Strings.Unbounded.To_Unbounded_String
           ("Library '" & Ref_Name & "' referenced by component '"
            & Comp_Name & "' does not exist");
         Fatal := True;
      end Error_Msg;
   begin
      Mucfgcheck.For_Each_Match
        (XML_Data     => XML_Data,
         Source_XPath => "/system/components/*/depends/library",
         Ref_XPath    => "/system/components/library",
         Log_Message  => "component library reference(s)",
         Error        => Error_Msg'Access,
         Match        => Match_Ref_Name'Access);
   end Component_Library_References;

   -------------------------------------------------------------------------

   procedure Component_Memory_Size (XML_Data : Muxml.XML_Data_Type)
   is
      Components  : constant DOM.Core.Node_List
        := McKae.XML.XPath.XIA.XPath_Query
          (N     => XML_Data.Doc,
           XPath => "/system/components/component");
      Phys_Memory : constant DOM.Core.Node_List
        := McKae.XML.XPath.XIA.XPath_Query
          (N     => XML_Data.Doc,
           XPath => "/system/memory/memory");
      Subjects    : constant DOM.Core.Node_List
        := McKae.XML.XPath.XIA.XPath_Query
          (N     => XML_Data.Doc,
           XPath => "/system/subjects/subject[component]");
   begin
      for I in 0 .. DOM.Core.Nodes.Length (List => Subjects) - 1 loop
         declare
            Subj_Node   : constant DOM.Core.Node
              := DOM.Core.Nodes.Item
                (List  => Subjects,
                 Index => I);
            Subj_Name   : constant String
              := DOM.Core.Elements.Get_Attribute
                (Elem => Subj_Node,
                 Name => "name");
            Comp_Name   : constant String
              := Muxml.Utils.Get_Attribute
                (Doc   => Subj_Node,
                 XPath => "component",
                 Name  => "ref");
            Comp_Node   : constant DOM.Core.Node
              := Muxml.Utils.Get_Element
                (Nodes     => Components,
                 Ref_Attr  => "name",
                 Ref_Value => Comp_Name);
            Comp_Memory : constant DOM.Core.Node_List
              := McKae.XML.XPath.XIA.XPath_Query
                (N     => Comp_Node,
                 XPath => "requires/memory/memory");
            Mem_Count   : constant Natural
              := DOM.Core.Nodes.Length (Comp_Memory);

            --  Check equality of logical and physical memory size.
            procedure Check_Mem_Size
              (Logical_Resource  : DOM.Core.Node;
               Physical_Resource : DOM.Core.Node);

            ----------------------------------------------------------------

            procedure Check_Mem_Size
              (Logical_Resource  : DOM.Core.Node;
               Physical_Resource : DOM.Core.Node)
            is
               use type Interfaces.Unsigned_64;

               Log_Mem_Name : constant String
                 := DOM.Core.Elements.Get_Attribute
                   (Elem => Logical_Resource,
                    Name => "logical");
               Log_Mem_Size : constant String
                 := DOM.Core.Elements.Get_Attribute
                   (Elem => Logical_Resource,
                    Name => "size");
               Phys_Mem_Size : constant String
                 := DOM.Core.Elements.Get_Attribute
                   (Elem => Physical_Resource,
                    Name => "size");
               Phys_Mem_Name : constant String
                 := DOM.Core.Elements.Get_Attribute
                   (Elem => Physical_Resource,
                    Name => "name");
            begin
               if Interfaces.Unsigned_64'Value (Log_Mem_Size)
                 /= Interfaces.Unsigned_64'Value (Phys_Mem_Size)
               then
                  Mucfgcheck.Validation_Errors.Insert
                    (Msg => "Component '"
                     & Comp_Name & "' referenced by subject '" & Subj_Name
                     & "' requests size " & Log_Mem_Size & " for logical "
                     & "memory '" & Log_Mem_Name & "' but linked physical "
                     & "memory region '" & Phys_Mem_Name & "' " & "has size "
                     & Phys_Mem_Size);
               end if;
            end Check_Mem_Size;
         begin
            if Mem_Count > 0 then
               Mulog.Log (Msg => "Checking size of" & Mem_Count'Img
                          & " component '" & Comp_Name & "' memory region(s) "
                          & "referenced by subject '" & Subj_Name & "'");

               Check_Component_Resources
                 (Logical_Resources  => Comp_Memory,
                  Physical_Resources => Phys_Memory,
                  Subject            => Subj_Node,
                  Check_Resource     => Check_Mem_Size'Access);
            end if;
         end;
      end loop;
   end Component_Memory_Size;

   -------------------------------------------------------------------------

   procedure Component_Name_Uniqueness (XML_Data : Muxml.XML_Data_Type)
   is
      Nodes : constant DOM.Core.Node_List
        := McKae.XML.XPath.XIA.XPath_Query
          (N     => XML_Data.Doc,
           XPath => "/system/components/component");
   begin
      Check_Attribute_Uniqueness
        (Nodes       => Nodes,
         Attr_Name   => "name",
         Description => "component");
   end Component_Name_Uniqueness;

   -------------------------------------------------------------------------

   procedure Device_RMRR_Domain_Assignment (XML_Data : Muxml.XML_Data_Type)
   is
      Regions   : constant DOM.Core.Node_List
        := McKae.XML.XPath.XIA.XPath_Query
          (N     => XML_Data.Doc,
           XPath => "/system/hardware/memory/reservedMemory");
      Reg_Count : constant Natural
        := DOM.Core.Nodes.Length (List => Regions);
      RMRR_Refs : constant DOM.Core.Node_List
        := McKae.XML.XPath.XIA.XPath_Query
          (N     => XML_Data.Doc,
           XPath => "/system/hardware/devices/device/reservedMemory");
      Mappings : constant DOM.Core.Node_List
        := McKae.XML.XPath.XIA.XPath_Query
          (N     => XML_Data.Doc,
           XPath => "/system/deviceDomains/domain/devices/device"
           & "[@mapReservedMemory='true']");
   begin
      if Reg_Count = 0 then
         return;
      end if;

      Mulog.Log (Msg => "Checking device domain assignment of" & Reg_Count'Img
                 & " reserved memory region(s)");

      for I in 1 .. Reg_Count loop
         declare
            Region      : constant DOM.Core.Node
              := DOM.Core.Nodes.Item (List  => Regions,
                                      Index => I - 1);
            Region_Name : constant String
              := DOM.Core.Elements.Get_Attribute (Elem => Region,
                                                  Name => "name");
            Refs        : constant DOM.Core.Node_List
              := Muxml.Utils.Get_Elements (Nodes     => RMRR_Refs,
                                           Ref_Attr  => "ref",
                                           Ref_Value => Region_Name);
            Refs_Count  : constant Natural
              := DOM.Core.Nodes.Length (List => Refs);
            Cur_Domain  : DOM.Core.Node;
         begin
            if Refs_Count < 2 then
               return;
            end if;

            for J in 1 .. Refs_Count loop
               declare
                  use type DOM.Core.Node;

                  Ref        : constant DOM.Core.Node
                    := DOM.Core.Nodes.Item (List  => Refs,
                                            Index => J - 1);
                  Dev_Name   : constant String
                    := DOM.Core.Elements.Get_Attribute
                      (Elem => DOM.Core.Nodes.Parent_Node (N => Ref),
                       Name => "name");
                  Ref_Domain : constant DOM.Core.Node
                    := Muxml.Utils.Ancestor_Node
                      (Node  => Muxml.Utils.Get_Element
                         (Nodes     => Mappings,
                          Ref_Attr  => "physical",
                          Ref_Value => Dev_Name),
                       Level => 2);
               begin
                  if Ref_Domain /= null then

                     --  Device is actually assigned to device domain and maps
                     --  RMRR.

                     if Cur_Domain = null then
                        Cur_Domain := Ref_Domain;
                     elsif Cur_Domain /= Ref_Domain then
                        declare
                           Cur_Dom_Name : constant String
                             := DOM.Core.Elements.Get_Attribute
                               (Elem => Cur_Domain,
                                Name => "name");
                           Ref_Dom_Name : constant String
                             := DOM.Core.Elements.Get_Attribute
                               (Elem => Ref_Domain,
                                Name => "name");
                        begin
                           Mucfgcheck.Validation_Errors.Insert
                             (Msg => "Device '"
                              & Dev_Name & "' referencing reserved memory "
                              & "region '" & Region_Name & "' assigned to "
                              & "different device domain than other device(s) "
                              & "referencing the same region: '" & Ref_Dom_Name
                              & "' vs '" & Cur_Dom_Name & "'");
                        end;
                     end if;
                  end if;
               end;
            end loop;
         end;
      end loop;
   end Device_RMRR_Domain_Assignment;

   -------------------------------------------------------------------------

   procedure Domain_Map_Subject_Memory_References (XML_Data : Muxml.XML_Data_Type)
   is
      --  Returns the error message for a given reference node.
      procedure Error_Msg
        (Node    :     DOM.Core.Node;
         Err_Str : out Ada.Strings.Unbounded.Unbounded_String;
         Fatal   : out Boolean);

      ----------------------------------------------------------------------

      procedure Error_Msg
        (Node    :     DOM.Core.Node;
         Err_Str : out Ada.Strings.Unbounded.Unbounded_String;
         Fatal   : out Boolean)
      is
         Subj_Name : constant String := DOM.Core.Elements.Get_Attribute
           (Elem => Node,
            Name => "subject");
         Devdom_Name : constant String := DOM.Core.Elements.Get_Attribute
           (Elem => Muxml.Utils.Ancestor_Node (Node  => Node,
                                               Level => 2),
            Name => "name");
      begin
         Err_Str := Ada.Strings.Unbounded.To_Unbounded_String
           ("Subject '" & Subj_Name
            & "' referenced by memory map directive in device domain '"
            & Devdom_Name & "' not found");
         Fatal := False;
      end Error_Msg;
   begin
      Mucfgcheck.For_Each_Match
        (XML_Data     => XML_Data,
         Source_XPath => "/system/deviceDomains/domain/memory/mapSubjectMemory",
         Ref_XPath    => "/system/subjects/subject",
         Log_Message  => "subject reference(s) in device domain map memory "
         & "directives",
         Error        => Error_Msg'Access,
         Match        => Mucfgcheck.Match_Subject_Name'Access);
   end Domain_Map_Subject_Memory_References;

   -------------------------------------------------------------------------

   procedure Hardware_CPU_Count_Presence (XML_Data : Muxml.XML_Data_Type)
   is
      Attr_Path : constant String := "/system/hardware/processor/@cpuCores";
      Attr      : constant DOM.Core.Node_List
        := McKae.XML.XPath.XIA.XPath_Query
          (N     => XML_Data.Doc,
           XPath => Attr_Path);
   begin
      Mulog.Log (Msg => "Checking presence of '" & Attr_Path & "' attribute");

      if DOM.Core.Nodes.Length (List => Attr) /= 1 then
         Mucfgcheck.Validation_Errors.Insert
           (Msg => "Required "
            & "'" & Attr_Path & "' attribute not found, add it or use "
            & "mucfgmerge tool");
      end if;
   end Hardware_CPU_Count_Presence;

   -------------------------------------------------------------------------

   procedure Hardware_IRQ_MSI_Name_Uniqueness (XML_Data : Muxml.XML_Data_Type)
   is
      MSI_Devices : constant DOM.Core.Node_List
        := McKae.XML.XPath.XIA.XPath_Query
          (N     => XML_Data.Doc,
           XPath => "/system/hardware/devices/device/irq[msi]/..");
      Dev_Count   : constant Natural
        := DOM.Core.Nodes.Length (List => MSI_Devices);
   begin
      for I in Natural range 0 .. Dev_Count - 1 loop
         declare
            Dev_Node  : constant DOM.Core.Node
              := DOM.Core.Nodes.Item (List  => MSI_Devices,
                                      Index => I);
            Dev_Name  : constant String
              := DOM.Core.Elements.Get_Attribute
                (Elem => Dev_Node,
                 Name => "name");
            MSI_Nodes : constant DOM.Core.Node_List
              := McKae.XML.XPath.XIA.XPath_Query
                (N     => Dev_Node,
                 XPath => "irq/msi");
         begin
            Check_Attribute_Uniqueness
              (Nodes       => MSI_Nodes,
               Attr_Name   => "name",
               Description => "device '" & Dev_Name & "' MSI IRQ");
         end;
      end loop;
   end Hardware_IRQ_MSI_Name_Uniqueness;

   -------------------------------------------------------------------------

   procedure Hardware_IRQ_Type_Consistency (XML_Data : Muxml.XML_Data_Type)
   is
      Phys_Devs : constant DOM.Core.Node_List
        := McKae.XML.XPath.XIA.XPath_Query
          (N     => XML_Data.Doc,
           XPath => "/system/hardware/devices/device[irq]");
      Log_Devs  : constant DOM.Core.Node_List
        := McKae.XML.XPath.XIA.XPath_Query
          (N     => XML_Data.Doc,
           XPath => "/system/subjects/subject/devices/device[irq"
           & " or (count(*)=1 and pci)]");
      Dev_Count : constant Natural
        := DOM.Core.Nodes.Length (List => Phys_Devs);
   begin
      Mulog.Log (Msg => "Checking IRQ type conformity of" & Dev_Count'Img
                 & " devices");

      for I in Natural range 0 .. Dev_Count - 1 loop
         declare
            Phys_Dev : constant DOM.Core.Node
              := DOM.Core.Nodes.Item (List  => Phys_Devs,
                                      Index => I);
            Phys_Name : constant String
              := DOM.Core.Elements.Get_Attribute
                (Elem => Phys_Dev,
                 Name => "name");
            Dev_Refs : constant DOM.Core.Node_List
              := Muxml.Utils.Get_Elements
                (Nodes     => Log_Devs,
                 Ref_Attr  => "physical",
                 Ref_Value => Phys_Name);
            Legacy_IRQ_Mode : Boolean;
         begin
            for J in Natural range 0 .. DOM.Core.Nodes.Length
              (List => Dev_Refs) - 1
            loop
               declare
                  Log_Dev : constant DOM.Core.Node
                    := DOM.Core.Nodes.Item (List  => Dev_Refs,
                                            Index => J);
                  Log_Dev_Name : constant String
                    := DOM.Core.Elements.Get_Attribute
                      (Elem => Log_Dev,
                       Name => "logical");
                  Subj_Name : constant String
                    := DOM.Core.Elements.Get_Attribute
                      (Elem => Muxml.Utils.Ancestor_Node
                           (Node  => Log_Dev,
                            Level => 2),
                       Name => "name");
                  Legacy_IRQs : constant DOM.Core.Node_List
                    := McKae.XML.XPath.XIA.XPath_Query
                      (N     => Log_Dev,
                       XPath => "irq[not (msi)]");
                  Legacy_IRQ_Count : constant Natural
                    := DOM.Core.Nodes.Length (List => Legacy_IRQs);
                  MSI_IRQs : constant DOM.Core.Node_List
                    := McKae.XML.XPath.XIA.XPath_Query
                      (N     => Log_Dev,
                       XPath => "irq[msi]");
                  MSI_IRQ_Count : constant Natural
                    := DOM.Core.Nodes.Length (List => MSI_IRQs);
               begin
                  if Legacy_IRQ_Count > 0 and then MSI_IRQ_Count > 0 then
                     Mucfgcheck.Validation_Errors.Insert
                       (Msg => "Logical device '"
                        & Log_Dev_Name & "' of subject '" & Subj_Name
                        & "' declares both legacy and MSI IRQ resources");
                  elsif Legacy_IRQ_Count > 0 then
                     if J = 0 then
                        Legacy_IRQ_Mode := True;
                     elsif not Legacy_IRQ_Mode then
                        Mucfgcheck.Validation_Errors.Insert
                          (Msg => "Physical device '" & Phys_Name
                           & "' has both legacy and MSI IRQ references");
                     end if;
                  else
                     if J = 0 then
                        Legacy_IRQ_Mode := False;
                     elsif Legacy_IRQ_Mode then
                        Mucfgcheck.Validation_Errors.Insert
                          (Msg   => "Physical device '" & Phys_Name
                           & "' has both legacy and MSI IRQ references");
                     end if;
                  end if;
               end;
            end loop;
         end;
      end loop;
   end Hardware_IRQ_Type_Consistency;

   -------------------------------------------------------------------------

   procedure Hardware_Reserved_Memory_Region_Name_Uniqueness
     (XML_Data : Muxml.XML_Data_Type)
   is
      Nodes : constant DOM.Core.Node_List
        := McKae.XML.XPath.XIA.XPath_Query
          (N     => XML_Data.Doc,
           XPath => "/system/hardware/memory/reservedMemory");
   begin
      Check_Attribute_Uniqueness
        (Nodes       => Nodes,
         Attr_Name   => "name",
         Description => "reserved memory region");
   end Hardware_Reserved_Memory_Region_Name_Uniqueness;

   -------------------------------------------------------------------------

   procedure Hardware_Reserved_Memory_Region_References
     (XML_Data : Muxml.XML_Data_Type)
   is
      --  Returns the error message for a given reference node.
      procedure Error_Msg
        (Node    :     DOM.Core.Node;
         Err_Str : out Ada.Strings.Unbounded.Unbounded_String;
         Fatal   : out Boolean);

      ----------------------------------------------------------------------

      procedure Error_Msg
        (Node    :     DOM.Core.Node;
         Err_Str : out Ada.Strings.Unbounded.Unbounded_String;
         Fatal   : out Boolean)
      is
         Ref_Region_Name : constant String := DOM.Core.Elements.Get_Attribute
           (Elem => Node,
            Name => "ref");
         Dev_Name        : constant String := DOM.Core.Elements.Get_Attribute
           (Elem => DOM.Core.Nodes.Parent_Node (N => Node),
            Name => "name");
      begin
         Err_Str := Ada.Strings.Unbounded.To_Unbounded_String
           ("Reserved region '" & Ref_Region_Name & "' referenced by "
            & "device '" & Dev_Name & "' does not exist");
         Fatal := True;
      end Error_Msg;
   begin
      Mucfgcheck.For_Each_Match
        (XML_Data     => XML_Data,
         Source_XPath => "/system/hardware/devices/device/reservedMemory",
         Ref_XPath    => "/system/hardware/memory/reservedMemory",
         Log_Message  => "reserved memory region reference(s)",
         Error        => Error_Msg'Access,
         Match        => Match_Ref_Name'Access);
   end Hardware_Reserved_Memory_Region_References;

   -------------------------------------------------------------------------

   procedure Library_Name_Uniqueness (XML_Data : Muxml.XML_Data_Type)
   is
      Nodes : constant DOM.Core.Node_List
        := McKae.XML.XPath.XIA.XPath_Query
          (N     => XML_Data.Doc,
           XPath => "/system/components/library");
   begin
      Check_Attribute_Uniqueness
        (Nodes       => Nodes,
         Attr_Name   => "name",
         Description => "library");
   end Library_Name_Uniqueness;

   -------------------------------------------------------------------------

   function Match_Ref_Name (Left, Right : DOM.Core.Node) return Boolean
   is
      Ref  : constant String := DOM.Core.Elements.Get_Attribute
        (Elem => Left,
         Name => "ref");
      Name : constant String := DOM.Core.Elements.Get_Attribute
        (Elem => Right,
         Name => "name");
   begin
      return Ref = Name;
   end Match_Ref_Name;

   ----------------------------------------------------------------------

   procedure Subject_Channel_Exports (XML_Data : Muxml.XML_Data_Type)
   is
      Phys_Channels : constant DOM.Core.Node_List
        := McKae.XML.XPath.XIA.XPath_Query
          (N     => XML_Data.Doc,
           XPath => "/system/channels/channel");
      Components : constant DOM.Core.Node_List
        := McKae.XML.XPath.XIA.XPath_Query
          (N     => XML_Data.Doc,
           XPath => "/system/components/component");
      Subjects   : constant DOM.Core.Node_List
        := McKae.XML.XPath.XIA.XPath_Query
          (N     => XML_Data.Doc,
           XPath => "/system/subjects/subject[component]");
   begin
      for I in 0 .. DOM.Core.Nodes.Length (List => Subjects) - 1
      loop
         declare
            Subj_Node     : constant DOM.Core.Node
              := DOM.Core.Nodes.Item
                (List  => Subjects,
                 Index => I);
            Comp_Name     : constant String
              := Muxml.Utils.Get_Attribute
                (Doc   => Subj_Node,
                 XPath => "component",
                 Name  => "ref");
            Comp_Node     : constant DOM.Core.Node
              := Muxml.Utils.Get_Element
                (Nodes     => Components,
                 Ref_Attr  => "name",
                 Ref_Value => Comp_Name);
            Comp_Channels : constant DOM.Core.Node_List
              := McKae.XML.XPath.XIA.XPath_Query
                (N     => Comp_Node,
                 XPath => "requires/channels//*"
                 & "[self::reader or self::writer]");
         begin
            Check_Component_Resource_Mappings
              (Logical_Resources  => Comp_Channels,
               Physical_Resources => Phys_Channels,
               Resource_Type      => "channel",
               Subject            => Subj_Node);
         end;
      end loop;
   end Subject_Channel_Exports;

   -------------------------------------------------------------------------

   procedure Subject_Channel_References (XML_Data : Muxml.XML_Data_Type)
   is
      --  Returns the error message for a given reference node.
      procedure Error_Msg
        (Node    :     DOM.Core.Node;
         Err_Str : out Ada.Strings.Unbounded.Unbounded_String;
         Fatal   : out Boolean);

      ----------------------------------------------------------------------

      procedure Error_Msg
        (Node    :     DOM.Core.Node;
         Err_Str : out Ada.Strings.Unbounded.Unbounded_String;
         Fatal   : out Boolean)
      is
         Ref_Channel_Name : constant String := DOM.Core.Elements.Get_Attribute
           (Elem => Node,
            Name => "physical");
         Subj_Name        : constant String := DOM.Core.Elements.Get_Attribute
           (Elem => Muxml.Utils.Ancestor_Node
              (Node  => Node,
               Level => 2),
            Name => "name");
      begin
         Err_Str := Ada.Strings.Unbounded.To_Unbounded_String
           ("Channel '" & Ref_Channel_Name & "' referenced by "
            & "subject '" & Subj_Name & "' does not exist");
         Fatal := True;
      end Error_Msg;
   begin
      Mucfgcheck.For_Each_Match
        (XML_Data     => XML_Data,
         Source_XPath => "/system/subjects/subject/channels/*",
         Ref_XPath    => "/system/channels/channel",
         Log_Message  => "subject channel reference(s)",
         Error        => Error_Msg'Access,
         Match        => Mutools.Match.Is_Valid_Reference'Access);
   end Subject_Channel_References;

   -------------------------------------------------------------------------

   procedure Subject_Component_References (XML_Data : Muxml.XML_Data_Type)
   is
      --  Returns the error message for a given reference node.
      procedure Error_Msg
        (Node    :     DOM.Core.Node;
         Err_Str : out Ada.Strings.Unbounded.Unbounded_String;
         Fatal   : out Boolean);

      ----------------------------------------------------------------------

      procedure Error_Msg
        (Node    :     DOM.Core.Node;
         Err_Str : out Ada.Strings.Unbounded.Unbounded_String;
         Fatal   : out Boolean)
      is
         Ref_Comp_Name : constant String := DOM.Core.Elements.Get_Attribute
           (Elem => Node,
            Name => "ref");
         Subj_Name     : constant String := DOM.Core.Elements.Get_Attribute
           (Elem => DOM.Core.Nodes.Parent_Node (N => Node),
            Name => "name");
      begin
         Err_Str := Ada.Strings.Unbounded.To_Unbounded_String
           ("Component '" & Ref_Comp_Name & "' referenced by subject '"
            & Subj_Name & "' does not exist");
         Fatal := True;
      end Error_Msg;
   begin
      Mucfgcheck.For_Each_Match
        (XML_Data     => XML_Data,
         Source_XPath => "/system/subjects/subject/component",
         Ref_XPath    => "/system/components/component",
         Log_Message  => "subject component reference(s)",
         Error        => Error_Msg'Access,
         Match        => Match_Ref_Name'Access);
   end Subject_Component_References;

   -------------------------------------------------------------------------

   procedure Subject_Component_Resource_Mappings
     (XML_Data : Muxml.XML_Data_Type)
   is
      Components : constant DOM.Core.Node_List
        := McKae.XML.XPath.XIA.XPath_Query
          (N     => XML_Data.Doc,
           XPath => "/system/components/component");
      Subjects   : constant DOM.Core.Node_List
        := McKae.XML.XPath.XIA.XPath_Query
          (N     => XML_Data.Doc,
           XPath => "/system/subjects/subject[component]");
   begin
      for I in 0 .. DOM.Core.Nodes.Length (List => Subjects) - 1 loop
         declare
            Subj_Node      : constant DOM.Core.Node
              := DOM.Core.Nodes.Item
                (List  => Subjects,
                 Index => I);
            Subj_Name      : constant String
              := DOM.Core.Elements.Get_Attribute
                (Elem => Subj_Node,
                 Name => "name");
            Mappings       : constant DOM.Core.Node_List
              := McKae.XML.XPath.XIA.XPath_Query
                (N     => Subj_Node,
                 XPath => "component/map");
            Comp_Name      : constant String
              := Muxml.Utils.Get_Attribute
                (Doc   => Subj_Node,
                 XPath => "component",
                 Name  => "ref");
            Comp_Node      : constant DOM.Core.Node
              := Muxml.Utils.Get_Element
                (Nodes     => Components,
                 Ref_Attr  => "name",
                 Ref_Value => Comp_Name);
            Comp_Resources : DOM.Core.Node_List
              := McKae.XML.XPath.XIA.XPath_Query
                (N     => Comp_Node,
                 XPath => "requires/devices/device");
            Comp_Channels  : constant DOM.Core.Node_List
              := McKae.XML.XPath.XIA.XPath_Query
                (N     => Comp_Node,
                 XPath => "requires/channels//*"
                 & "[self::reader or self::writer]");
            Comp_Memory    : constant DOM.Core.Node_List
              := McKae.XML.XPath.XIA.XPath_Query
                (N     => Comp_Node,
                 XPath => "requires/memory/memory");
            Comp_Events    : constant DOM.Core.Node_List
              := McKae.XML.XPath.XIA.XPath_Query
                (N     => Comp_Node,
                 XPath => "requires/events/*/event");
         begin
            Muxml.Utils.Append (Left  => Comp_Resources,
                                Right => Comp_Channels);
            Muxml.Utils.Append (Left  => Comp_Resources,
                                Right => Comp_Memory);
            Muxml.Utils.Append (Left  => Comp_Resources,
                                Right => Comp_Events);

            Mulog.Log (Msg => "Checking component resource mappings of "
                       & "subject '" & Subj_Name & "'");

            for J in 0 .. DOM.Core.Nodes.Length (List => Mappings) - 1 loop
               declare
                  use type DOM.Core.Node;

                  Map_Node : constant DOM.Core.Node
                    := DOM.Core.Nodes.Item (List  => Mappings,
                                            Index => J);
                  Log_Name : constant String
                    := DOM.Core.Elements.Get_Attribute
                      (Elem => Map_Node,
                       Name => "logical");
                  Comp_Res : constant DOM.Core.Node
                    := Muxml.Utils.Get_Element
                      (Nodes     => Comp_Resources,
                       Ref_Attr  => "logical",
                       Ref_Value => Log_Name);
               begin
                  if Comp_Res = null then
                     Mucfgcheck.Validation_Errors.Insert
                       (Msg => "Subject '"
                        & Subj_Name & "' maps logical resource '" & Log_Name
                        & "' which is not requested by component '"
                        & Comp_Name & "'");
                  end if;
               end;
            end loop;
         end;
      end loop;
   end Subject_Component_Resource_Mappings;

   -------------------------------------------------------------------------

   procedure Subject_Device_Exports (XML_Data : Muxml.XML_Data_Type)
   is
      Phys_Devices : constant DOM.Core.Node_List
        := McKae.XML.XPath.XIA.XPath_Query
          (N     => XML_Data.Doc,
           XPath => "/system/hardware/devices/device");
      Components   : constant DOM.Core.Node_List
        := McKae.XML.XPath.XIA.XPath_Query
          (N     => XML_Data.Doc,
           XPath => "/system/components/component");
      Subjects     : constant DOM.Core.Node_List
        := McKae.XML.XPath.XIA.XPath_Query
          (N     => XML_Data.Doc,
           XPath => "/system/subjects/subject[component]");
   begin
      for I in 0 .. DOM.Core.Nodes.Length (List => Subjects) - 1 loop
         declare
            Subj_Node    : constant DOM.Core.Node
              := DOM.Core.Nodes.Item
                (List  => Subjects,
                 Index => I);
            Comp_Name    : constant String
              := Muxml.Utils.Get_Attribute
                (Doc   => Subj_Node,
                 XPath => "component",
                 Name  => "ref");
            Comp_Node    : constant DOM.Core.Node
              := Muxml.Utils.Get_Element
                (Nodes     => Components,
                 Ref_Attr  => "name",
                 Ref_Value => Comp_Name);
            Comp_Devices : constant DOM.Core.Node_List
              := McKae.XML.XPath.XIA.XPath_Query
                (N     => Comp_Node,
                 XPath => "requires/devices/device");

            --  Check that all logical device resources are mapped to physical
            --  device resources of the same type.
            procedure Check_Device_Resource_Mappings
              (Logical_Device  : DOM.Core.Node;
               Physical_Device : DOM.Core.Node;
               Mapping         : DOM.Core.Node);

            ----------------------------------------------------------------

            procedure Check_Device_Resource_Mappings
              (Logical_Device  : DOM.Core.Node;
               Physical_Device : DOM.Core.Node;
               Mapping         : DOM.Core.Node)
            is
               Subj_Name     : constant String
                 := DOM.Core.Elements.Get_Attribute
                   (Elem => Muxml.Utils.Ancestor_Node
                      (Node  => Mapping,
                       Level => 2),
                    Name => "name");
               Log_Dev_Name  : constant String
                 := DOM.Core.Elements.Get_Attribute
                   (Elem => Logical_Device,
                    Name => "logical");
               Phys_Dev_Name : constant String
                 := DOM.Core.Elements.Get_Attribute
                   (Elem => Physical_Device,
                    Name => "name");
               Res_Mappings  : constant DOM.Core.Node_List
                 := McKae.XML.XPath.XIA.XPath_Query
                   (N     => Mapping,
                    XPath => "*");
               Log_Dev_Res   : constant DOM.Core.Node_List
                 := McKae.XML.XPath.XIA.XPath_Query
                   (N     => Logical_Device,
                    XPath => "*");
               Phys_Dev_Res  : constant DOM.Core.Node_List
                 := McKae.XML.XPath.XIA.XPath_Query
                   (N     => Physical_Device,
                    XPath => "*");
            begin
               for I in 0 .. DOM.Core.Nodes.Length (List => Log_Dev_Res) - 1
               loop
                  declare
                     use type DOM.Core.Node;

                     Log_Res : constant DOM.Core.Node
                       := DOM.Core.Nodes.Item (List  => Log_Dev_Res,
                                               Index => I);
                     Log_Res_Name : constant String
                       := DOM.Core.Elements.Get_Attribute
                         (Elem => Log_Res,
                          Name => "logical");
                     Phys_Res_Name : constant String
                       := Muxml.Utils.Get_Attribute
                         (Nodes     => Res_Mappings,
                          Ref_Attr  => "logical",
                          Ref_Value => Log_Res_Name,
                          Attr_Name => "physical");
                     Phys_Res : constant DOM.Core.Node
                       := Muxml.Utils.Get_Element
                         (Nodes     => Phys_Dev_Res,
                          Ref_Attr  => "name",
                          Ref_Value => Phys_Res_Name);
                  begin
                     if Phys_Res_Name'Length = 0 then
                        Mucfgcheck.Validation_Errors.Insert
                          (Msg => "Subject '"
                           & Subj_Name & "' does not map logical device "
                           & "resource '" & Log_Dev_Name & "->" & Log_Res_Name
                           & "' as requested by referenced component '"
                           & Comp_Name & "'");
                     end if;

                     if Phys_Res = null then
                        Mucfgcheck.Validation_Errors.Insert
                          (Msg => "Physical "
                           & "device resource '" & Phys_Dev_Name & "->"
                           & Phys_Res_Name & "' referenced by "
                           & "mapping of component logical resource '"
                           & Log_Dev_Name & "->" & Log_Res_Name
                           & "' by subject" & " '" & Subj_Name
                           & "' does not exist");
                        return;
                     end if;

                     if DOM.Core.Nodes.Node_Name (N => Log_Res)
                       /= DOM.Core.Nodes.Node_Name (N => Phys_Res)
                     then
                        Mucfgcheck.Validation_Errors.Insert
                          (Msg => "Physical "
                           & "device resource '" & Phys_Dev_Name & "->"
                           & Phys_Res_Name & "' and component logical resource"
                           & " '" & Log_Dev_Name & "->" & Log_Res_Name
                           & "' mapped by subject" & " '" & Subj_Name
                           & "' have different type");
                     end if;
                  end;
               end loop;
            end Check_Device_Resource_Mappings;
         begin
            Check_Component_Resource_Mappings
              (Logical_Resources  => Comp_Devices,
               Physical_Resources => Phys_Devices,
               Resource_Type      => "device",
               Subject            => Subj_Node,
               Additional_Check   => Check_Device_Resource_Mappings'Access);
         end;
      end loop;
   end Subject_Device_Exports;

   -------------------------------------------------------------------------

   procedure Subject_Event_Exports (XML_Data : Muxml.XML_Data_Type)
   is
      Phys_Events : constant DOM.Core.Node_List
        := McKae.XML.XPath.XIA.XPath_Query
          (N     => XML_Data.Doc,
           XPath => "/system/events/event");
      Components : constant DOM.Core.Node_List
        := McKae.XML.XPath.XIA.XPath_Query
          (N     => XML_Data.Doc,
           XPath => "/system/components/component");
      Subjects   : constant DOM.Core.Node_List
        := McKae.XML.XPath.XIA.XPath_Query
          (N     => XML_Data.Doc,
           XPath => "/system/subjects/subject[component]");
   begin
      for I in 0 .. DOM.Core.Nodes.Length (List => Subjects) - 1 loop
         declare
            Subj_Node  : constant DOM.Core.Node
              := DOM.Core.Nodes.Item
                (List  => Subjects,
                 Index => I);
            Comp_Name  : constant String
              := Muxml.Utils.Get_Attribute
                (Doc   => Subj_Node,
                 XPath => "component",
                 Name  => "ref");
            Comp_Node  : constant DOM.Core.Node
              := Muxml.Utils.Get_Element
                (Nodes     => Components,
                 Ref_Attr  => "name",
                 Ref_Value => Comp_Name);
            Comp_Events : constant DOM.Core.Node_List
              := McKae.XML.XPath.XIA.XPath_Query
                (N     => Comp_Node,
                 XPath => "requires/events/*/event");
         begin
            Check_Component_Resource_Mappings
              (Logical_Resources  => Comp_Events,
               Physical_Resources => Phys_Events,
               Resource_Type      => "event",
               Subject            => Subj_Node);
         end;
      end loop;
   end Subject_Event_Exports;

   -------------------------------------------------------------------------

   procedure Subject_IRQ_MSI_Name_Uniqueness (XML_Data : Muxml.XML_Data_Type)
   is
      Subj_MSI_Devices : constant DOM.Core.Node_List
        := McKae.XML.XPath.XIA.XPath_Query
          (N     => XML_Data.Doc,
           XPath => "/system/subjects/subject/devices/device/irq[msi]/..");
      Dev_Count : constant Natural
        := DOM.Core.Nodes.Length (List => Subj_MSI_Devices);
   begin
      for I in Natural range 0 .. Dev_Count - 1 loop
         declare
            Dev_Node  : constant DOM.Core.Node
              := DOM.Core.Nodes.Item (List  => Subj_MSI_Devices,
                                      Index => I);
            Dev_Name  : constant String
              := DOM.Core.Elements.Get_Attribute
                (Elem => Dev_Node,
                 Name => "logical");
            Subj_Name : constant String
              := DOM.Core.Elements.Get_Attribute
                (Elem => Muxml.Utils.Ancestor_Node
                     (Node  => Dev_Node,
                      Level => 2),
                 Name => "name");
            MSI_Nodes : constant DOM.Core.Node_List
              := McKae.XML.XPath.XIA.XPath_Query
                (N     => Dev_Node,
                 XPath => "irq/msi");
         begin
            Check_Attribute_Uniqueness
              (Nodes       => MSI_Nodes,
               Attr_Name   => "logical",
               Description => "subject '" & Subj_Name & "' device '"
               & Dev_Name & "' MSI IRQ");
         end;
      end loop;
   end Subject_IRQ_MSI_Name_Uniqueness;

   -------------------------------------------------------------------------

   procedure Subject_IRQ_MSI_References (XML_Data : Muxml.XML_Data_Type)
   is
      Phys_MSI_Devs : constant DOM.Core.Node_List
        := McKae.XML.XPath.XIA.XPath_Query
          (N     => XML_Data.Doc,
           XPath => "/system/hardware/devices/device/irq[msi]/..");
      Subj_MSI_Devs : constant DOM.Core.Node_List
        := McKae.XML.XPath.XIA.XPath_Query
          (N     => XML_Data.Doc,
           XPath => "/system/subjects/subject/devices/device/irq[msi]/..");
      Dev_Count : constant Natural
        := DOM.Core.Nodes.Length (List => Subj_MSI_Devs);
   begin
      for I in Natural range 0 .. Dev_Count - 1 loop
         declare
            use type DOM.Core.Node;

            Subj_Dev : constant DOM.Core.Node
              := DOM.Core.Nodes.Item (List  => Subj_MSI_Devs,
                                      Index => I);
            Subj_Name : constant String
              := DOM.Core.Elements.Get_Attribute
                (Elem => Muxml.Utils.Ancestor_Node (Node  => Subj_Dev,
                                                    Level => 2),
                 Name => "name");
            Log_MSIs : constant DOM.Core.Node_List
              := McKae.XML.XPath.XIA.XPath_Query
                (N     => Subj_Dev,
                 XPath => "irq/msi");
            Log_Dev_Name : constant String
              := DOM.Core.Elements.Get_Attribute (Elem => Subj_Dev,
                                                  Name => "logical");
            Phys_Dev_Name : constant String
              := DOM.Core.Elements.Get_Attribute (Elem => Subj_Dev,
                                                  Name => "physical");
            Phys_Dev : constant DOM.Core.Node
              := Muxml.Utils.Get_Element (Nodes     => Phys_MSI_Devs,
                                          Ref_Attr  => "name",
                                          Ref_Value => Phys_Dev_Name);
            Phys_MSIs : DOM.Core.Node_List;
         begin

            --  Skip logical device references to aliases/device classes.

            if Phys_Dev /= null then
               Phys_MSIs := McKae.XML.XPath.XIA.XPath_Query
                 (N     => Phys_Dev,
                  XPath => "irq/msi");
               for J in Natural range 0 .. DOM.Core.Nodes.Length
                 (List => Log_MSIs) - 1
               loop
                  declare
                     Log_MSI       : constant DOM.Core.Node
                       := DOM.Core.Nodes.Item (List  => Log_MSIs,
                                               Index => J);
                     Phys_MSI_Name : constant String
                       := DOM.Core.Elements.Get_Attribute
                         (Elem => Log_MSI,
                          Name => "physical");
                     Phys_MSI      : constant DOM.Core.Node
                       := Muxml.Utils.Get_Element
                         (Nodes     => Phys_MSIs,
                          Ref_Attr  => "name",
                          Ref_Value => Phys_MSI_Name);
                  begin
                     if Phys_MSI = null then
                        declare
                           Log_IRQ : constant DOM.Core.Node
                             := DOM.Core.Nodes.Parent_Node (N => Log_MSI);
                           Log_IRQ_Name : constant String
                             := DOM.Core.Elements.Get_Attribute
                               (Elem => Log_IRQ,
                                Name => "logical");
                           Phys_IRQ_Name : constant String
                             := DOM.Core.Elements.Get_Attribute
                               (Elem => Log_IRQ,
                                Name => "logical");
                           Log_MSI_Name : constant String
                             := DOM.Core.Elements.Get_Attribute
                               (Elem => Log_MSI,
                                Name => "logical");
                        begin
                           Mucfgcheck.Validation_Errors.Insert
                             (Msg => "Logical "
                              & "device '" & Log_Dev_Name & "->" & Log_IRQ_Name
                              & "->" & Log_MSI_Name & "' of subject '"
                              & Subj_Name & "' references non-existent "
                              & "physical device MSI '" & Phys_Dev_Name & "->"
                              & Phys_IRQ_Name & "->" & Phys_MSI_Name & "'");
                        end;
                     end if;
                  end;
               end loop;
            end if;
         end;
      end loop;
   end Subject_IRQ_MSI_References;

   -------------------------------------------------------------------------

   procedure Subject_Memory_Exports (XML_Data : Muxml.XML_Data_Type)
   is
      Phys_Memory : constant DOM.Core.Node_List
        := McKae.XML.XPath.XIA.XPath_Query
          (N     => XML_Data.Doc,
           XPath => "/system/memory/memory");
      Components : constant DOM.Core.Node_List
        := McKae.XML.XPath.XIA.XPath_Query
          (N     => XML_Data.Doc,
           XPath => "/system/components/component");
      Subjects   : constant DOM.Core.Node_List
        := McKae.XML.XPath.XIA.XPath_Query
          (N     => XML_Data.Doc,
           XPath => "/system/subjects/subject[component]");
   begin
      for I in 0 .. DOM.Core.Nodes.Length (List => Subjects) - 1 loop
         declare
            Subj_Node  : constant DOM.Core.Node
              := DOM.Core.Nodes.Item
                (List  => Subjects,
                 Index => I);
            Comp_Name  : constant String
              := Muxml.Utils.Get_Attribute
                (Doc   => Subj_Node,
                 XPath => "component",
                 Name  => "ref");
            Comp_Node  : constant DOM.Core.Node
              := Muxml.Utils.Get_Element
                (Nodes     => Components,
                 Ref_Attr  => "name",
                 Ref_Value => Comp_Name);
            Comp_Memory : constant DOM.Core.Node_List
              := McKae.XML.XPath.XIA.XPath_Query
                (N     => Comp_Node,
                 XPath => "requires/memory//memory");
         begin
            Check_Component_Resource_Mappings
              (Logical_Resources  => Comp_Memory,
               Physical_Resources => Phys_Memory,
               Resource_Type      => "memory region",
               Subject            => Subj_Node);
         end;
      end loop;
   end Subject_Memory_Exports;

   -------------------------------------------------------------------------

   procedure Subject_Monitor_Loader_Addresses (XML_Data : Muxml.XML_Data_Type)
   is
      subtype Valid_Address_Range is Interfaces.Unsigned_64 range
        16#1_0000_0000# .. 16#6fff_ffff_ffff#;

      Loader_Nodes : constant DOM.Core.Node_List
        := McKae.XML.XPath.XIA.XPath_Query
          (N     => XML_Data.Doc,
           XPath => "/system/subjects/subject/monitor/loader");
      Loader_Count : constant Natural
        := DOM.Core.Nodes.Length (List => Loader_Nodes);
   begin
      if Loader_Count = 0 then
         return;
      end if;

      Mulog.Log (Msg => "Checking range of" & Loader_Count'Img
                 & " loader virtual addresse(s)");

      for I in Natural range 0 .. Loader_Count - 1 loop
         declare
            Ldr_Node  : constant DOM.Core.Node
              := DOM.Core.Nodes.Item (List  => Loader_Nodes,
                                      Index => I);
            Loadee_Name : constant String
              := DOM.Core.Elements.Get_Attribute
                (Elem => Ldr_Node,
                 Name => "subject");
            Subject_Name : constant String
              := DOM.Core.Elements.Get_Attribute
                (Elem => Muxml.Utils.Ancestor_Node
                     (Node  => Ldr_Node,
                      Level => 2),
                 Name => "name");
            Self_Load : constant Boolean := Loadee_Name = Subject_Name;
            Virt_Addr : constant Interfaces.Unsigned_64
              := Interfaces.Unsigned_64'Value
                (DOM.Core.Elements.Get_Attribute (Elem => Ldr_Node,
                                                  Name => "virtualAddress"));
         begin
            if not Self_Load and then Virt_Addr not in Valid_Address_Range then
               declare
                  Ldr_Logical  : constant String
                    := DOM.Core.Elements.Get_Attribute
                      (Elem => Ldr_Node,
                       Name => "logical");
                  Subject_Name : constant String
                    := DOM.Core.Elements.Get_Attribute
                      (Elem => Muxml.Utils.Ancestor_Node (Node  => Ldr_Node,
                                                          Level => 2),
                       Name => "name");
               begin
                  Mucfgcheck.Validation_Errors.Insert
                    (Msg => "Loader mapping '"
                     & Ldr_Logical & "' of subject '" & Subject_Name & "' not "
                     & "in valid range " & Mutools.Utils.To_Hex
                       (Number => Valid_Address_Range'First)
                     & " .. " & Mutools.Utils.To_Hex
                       (Number => Valid_Address_Range'Last));
               end;
            end if;
         end;
      end loop;
   end Subject_Monitor_Loader_Addresses;

   -------------------------------------------------------------------------

   procedure Subject_Monitor_References (XML_Data : Muxml.XML_Data_Type)
   is
      --  Returns the error message for a given reference node.
      procedure Error_Msg
        (Node    :     DOM.Core.Node;
         Err_Str : out Ada.Strings.Unbounded.Unbounded_String;
         Fatal   : out Boolean);

      ----------------------------------------------------------------------

      procedure Error_Msg
        (Node    :     DOM.Core.Node;
         Err_Str : out Ada.Strings.Unbounded.Unbounded_String;
         Fatal   : out Boolean)
      is
         Ref_Subj_Name : constant String := DOM.Core.Elements.Get_Attribute
           (Elem => Node,
            Name => "subject");
         Subj_Name     : constant String := DOM.Core.Elements.Get_Attribute
           (Elem => Muxml.Utils.Ancestor_Node
              (Node  => Node,
               Level => 2),
            Name => "name");
      begin
         Err_Str := Ada.Strings.Unbounded.To_Unbounded_String
           ("Subject '" & Ref_Subj_Name & "' referenced by subject monitor"
            & " '" & Subj_Name & "' does not exist");
         Fatal := True;
      end Error_Msg;
   begin
      Mucfgcheck.For_Each_Match
        (XML_Data     => XML_Data,
         Source_XPath => "/system/subjects/subject/monitor/*[@subject]",
         Ref_XPath    => "/system/subjects/subject",
         Log_Message  => "subject monitor reference(s)",
         Error        => Error_Msg'Access,
         Match        => Mucfgcheck.Match_Subject_Name'Access);
   end Subject_Monitor_References;

   -------------------------------------------------------------------------

   procedure Subject_Resource_Maps_Logical_Uniqueness
     (XML_Data : Muxml.XML_Data_Type)
   is
   begin
      Check_Subject_Resource_Maps_Attr_Uniqueness
        (XML_Data => XML_Data,
         Attr     => "logical");
   end Subject_Resource_Maps_Logical_Uniqueness;

   -------------------------------------------------------------------------

   procedure Subject_Sibling_Bootparams (XML_Data : Muxml.XML_Data_Type)
   is
      Siblings : constant DOM.Core.Node_List
        := McKae.XML.XPath.XIA.XPath_Query
          (N     => XML_Data.Doc,
           XPath => "/system/subjects/subject[sibling]");
   begin
      for I in 0 ..  DOM.Core.Nodes.Length (List => Siblings) - 1 loop
         declare
            use type DOM.Core.Node;

            Subj_Node  : constant DOM.Core.Node
              := DOM.Core.Nodes.Item
                (List  => Siblings,
                 Index => I);
            Bootparams : constant String
              := Muxml.Utils.Get_Element_Value
                (Doc   => Subj_Node,
                 XPath => "bootparams");
         begin
            if Bootparams'Length > 0 then
               declare
                  Subj_Name : constant String
                    := DOM.Core.Elements.Get_Attribute
                      (Elem => Subj_Node,
                       Name => "name");
                  Sib_Name  : constant String
                    := Muxml.Utils.Get_Attribute
                      (Doc   => Subj_Node,
                       XPath => "sibling",
                       Name  => "ref");
               begin
                  Mucfgcheck.Validation_Errors.Insert
                    (Msg => "Subject '"
                     & Subj_Name & "' which is a sibling of '" & Sib_Name
                     & "' specifies boot parameters");
               end;
            end if;
         end;
      end loop;
   end Subject_Sibling_Bootparams;

   -------------------------------------------------------------------------

   procedure Subject_Sibling_Device_BDFs (XML_Data : Muxml.XML_Data_Type)
   is
      Subjects : constant DOM.Core.Node_List
        := McKae.XML.XPath.XIA.XPath_Query
          (N     => XML_Data.Doc,
           XPath => "/system/subjects/subject"
           & "[not(sibling) and @profile='linux']");
   begin
      for I in 0 .. DOM.Core.Nodes.Length (List => Subjects) - 1 loop
         declare
            Subj_Node : constant DOM.Core.Node
              := DOM.Core.Nodes.Item
                (List  => Subjects,
                 Index => I);
            Subj_Name : constant String
              := DOM.Core.Elements.Get_Attribute
                (Elem => Subj_Node,
                 Name => "name");
            BDFs : DOM.Core.Node_List
              := McKae.XML.XPath.XIA.XPath_Query
                (N     => Subj_Node,
                 XPath => "devices/device/pci");
            Sib_PCI : constant DOM.Core.Node_List
              := McKae.XML.XPath.XIA.XPath_Query
                (N     => XML_Data.Doc,
                 XPath => "/system/subjects/subject/sibling[@ref='"
                 & Subj_Name & "']/../devices/device/pci");

            --  Check that BDFs of Left and Right are identical if the same
            --  physical device is referenced.
            --  Also check that BDFs of Left and Right are unequal if different
            --  physical devices are referenced.
            procedure Check_BDF (Left, Right : DOM.Core.Node);

            ----------------------------------------------------------------

            procedure Check_BDF (Left, Right : DOM.Core.Node)
            is
               Left_Dev_Name : constant String
                 := DOM.Core.Elements.Get_Attribute
                   (Elem => DOM.Core.Nodes.Parent_Node (N => Left),
                    Name => "logical");
               Right_Dev_Name : constant String
                 := DOM.Core.Elements.Get_Attribute
                   (Elem => DOM.Core.Nodes.Parent_Node (N => Right),
                    Name => "logical");
               Left_Phys_Dev_Name : constant String
                 := DOM.Core.Elements.Get_Attribute
                   (Elem => DOM.Core.Nodes.Parent_Node (N => Left),
                    Name => "physical");
               Right_Phys_Dev_Name : constant String
                 := DOM.Core.Elements.Get_Attribute
                   (Elem => DOM.Core.Nodes.Parent_Node (N => Right),
                    Name => "physical");
               Left_Subj_Name : constant String
                 := DOM.Core.Elements.Get_Attribute
                   (Elem => Muxml.Utils.Ancestor_Node
                      (Node  => Left,
                       Level => 3),
                    Name => "name");
               Right_Subj_Name : constant String
                 := DOM.Core.Elements.Get_Attribute
                   (Elem => Muxml.Utils.Ancestor_Node
                      (Node  => Right,
                       Level => 3),
                    Name => "name");
            begin
               if Left_Phys_Dev_Name = Right_Phys_Dev_Name and then not
                 Mutools.XML_Utils.Equal_BDFs
                   (Left  => Left,
                    Right => Right)
               then
                  Mucfgcheck.Validation_Errors.Insert
                    (Msg => "Linux sibling '"
                     & Left_Subj_Name & "' logical device '" & Left_Dev_Name
                     & "' PCI BDF not equal to logical device '"
                     & Right_Dev_Name & "' of sibling '" & Right_Subj_Name
                     & "' referencing same physdev");
               elsif Left_Phys_Dev_Name /= Right_Phys_Dev_Name and then
                 Mutools.XML_Utils.Equal_BDFs
                   (Left  => Left,
                    Right => Right)
               then
                  Mucfgcheck.Validation_Errors.Insert
                    (Msg => "Logical device '"
                     & Left_Dev_Name & "' of Linux sibling '"
                     & Left_Subj_Name & "' has equal PCI BDF with logical "
                     & "device '" & Right_Dev_Name & "' of sibling '"
                     & Right_Subj_Name & "'");
               end if;
            end Check_BDF;
         begin
            if DOM.Core.Nodes.Length (List => Sib_PCI) > 0 then
               Mulog.Log
                 (Msg => "Checking PCI BDFs of devices associated to '"
                  & Subj_Name & "' siblings");

               for J in 0 .. DOM.Core.Nodes.Length (List => Sib_PCI) - 1 loop
                  DOM.Core.Append_Node
                    (List => BDFs,
                     N    => DOM.Core.Nodes.Item
                       (List  => Sib_PCI,
                        Index => J));
               end loop;

               Mucfgcheck.Compare_All
                 (Nodes      => BDFs,
                  Comparator => Check_BDF'Access);
            end if;
         end;
      end loop;
   end Subject_Sibling_Device_BDFs;

   -------------------------------------------------------------------------

   procedure Subject_Sibling_Memory (XML_Data : Muxml.XML_Data_Type)
   is
      Siblings : constant DOM.Core.Node_List
        := McKae.XML.XPath.XIA.XPath_Query
          (N     => XML_Data.Doc,
           XPath => "/system/subjects/subject[sibling]");
   begin
      for I in 0 ..  DOM.Core.Nodes.Length (List => Siblings) - 1 loop
         declare
            use type DOM.Core.Node;

            Subj_Node  : constant DOM.Core.Node
              := DOM.Core.Nodes.Item
                (List  => Siblings,
                 Index => I);
            Memory : constant DOM.Core.Node_List
              := McKae.XML.XPath.XIA.XPath_Query (N     => Subj_Node,
                                                  XPath => "memory/memory");
         begin
            if DOM.Core.Nodes.Length (List => Memory) > 0 then
               declare
                  Subj_Name : constant String
                    := DOM.Core.Elements.Get_Attribute
                      (Elem => Subj_Node,
                       Name => "name");
                  Sib_Name  : constant String
                    := Muxml.Utils.Get_Attribute
                      (Doc   => Subj_Node,
                       XPath => "sibling",
                       Name  => "ref");
               begin
                  Mucfgcheck.Validation_Errors.Insert
                    (Msg => "Subject '"
                     & Subj_Name & "' which is a sibling of '" & Sib_Name
                     & "' specifies additional memory");
               end;
            end if;
         end;
      end loop;
   end Subject_Sibling_Memory;

   -------------------------------------------------------------------------

   procedure Subject_Sibling_References (XML_Data : Muxml.XML_Data_Type)
   is
      --  Returns the error message for a given reference node.
      procedure Error_Msg
        (Node    :     DOM.Core.Node;
         Err_Str : out Ada.Strings.Unbounded.Unbounded_String;
         Fatal   : out Boolean);

      ----------------------------------------------------------------------

      procedure Error_Msg
        (Node    :     DOM.Core.Node;
         Err_Str : out Ada.Strings.Unbounded.Unbounded_String;
         Fatal   : out Boolean)
      is
         Ref_Sib_Name : constant String := DOM.Core.Elements.Get_Attribute
           (Elem => Node,
            Name => "ref");
         Subj_Name : constant String := DOM.Core.Elements.Get_Attribute
           (Elem => DOM.Core.Nodes.Parent_Node (N => Node),
            Name => "name");
      begin
         Err_Str := Ada.Strings.Unbounded.To_Unbounded_String
           ("Sibling '" & Ref_Sib_Name & "' referenced by subject '"
            & Subj_Name & "' does not exist");
         Fatal := True;
      end Error_Msg;
   begin
      Mucfgcheck.For_Each_Match
        (XML_Data     => XML_Data,
         Source_XPath => "/system/subjects/subject/sibling",
         Ref_XPath    => "/system/subjects/subject[not(sibling)]",
         Log_Message  => "subject sibling reference(s)",
         Error        => Error_Msg'Access,
         Match        => Match_Ref_Name'Access);
   end Subject_Sibling_References;

   -------------------------------------------------------------------------

   procedure Tau0_Presence_In_Scheduling (XML_Data : Muxml.XML_Data_Type)
   is
   begin
      if not Mutools.XML_Utils.Is_Tau0_Scheduled (Data => XML_Data) then
         Mulog.Log
           (Msg => "Checking number of major frames (no Tau0 subject present)");

         if Mutools.XML_Utils.Has_Multiple_Major_Frames (Data => XML_Data)
         then
            Mucfgcheck.Validation_Errors.Insert
              (Msg => "Tau0 subject not present but multiple major frames"
               & " specified");
         end if;
      end if;
   end Tau0_Presence_In_Scheduling;

end Cfgchecks;
