--
--  Copyright (C) 2022 secunet Security Networks AG
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
with Ada.Strings.Fixed;

with DOM.Core.Nodes;
with DOM.Core.Elements;

with McKae.XML.XPath.XIA;

with Mulog;
with Muxml.Utils;

package body Mutools.Expressions.Case_Expression
is
   --  To be called on nodes like <boolean value="foo"/> as well as
   --  config-variable entries like <boolean name="varname" value="foo"/>
   --  (independent of the type of the variable).
   --  Sets Type_And_Value with the respective type-value tuple.
   --  If value begins with '$', an error will be reported.
   procedure Get_Type_And_Value
      (Node           :     DOM.Core.Node;
       Type_And_Value : out Value_Type_Tuple);

   -------------------------------------------------------------------------

   --  Evaluate a Case-Statement within an expression recursively.
   procedure Evaluate_Case_Node
      (Case_Node     :        DOM.Core.Node;
       Value_Of_Case :    out Value_Type_Tuple;
       Backtrace     : in out String_Vector.Vector;
       Node_Access   : in out Access_Hashmaps_Type);

   -------------------------------------------------------------------------

   --  Assign the value of the variable or expression with name Ref_Name to
   --  Result. This triggers expansion of that node if necessary.
   procedure Get_Value_Of_Reference
      (Ref_Name    :        String;
       Result      :    out Value_Type_Tuple;
       Backtrace   : in out String_Vector.Vector;
       Node_Access : in out Access_Hashmaps_Type);

   -------------------------------------------------------------------------

   function "=" (L, R : Value_Type_Tuple) return Boolean
   is
   begin
      if L.Value_Type /= R.Value_Type then
         return False;
      end if;
      case L.Value_Type is
         when Boolean_Type =>
            return L.Bool_Value = R.Bool_Value;
         when Integer_Type =>
            return L.Int_Value = R.Int_Value;
         when String_Type =>
            return L.String_Value.Element = R.String_Value.Element;
      end case;
   end "=";

   -------------------------------------------------------------------------

   procedure Case_Expression_Evaluation
      (Expr_Node     :        DOM.Core.Node;
       Value_Of_Case :    out Value_Type_Tuple;
       Backtrace     : in out String_Vector.Vector;
       Node_Access   : in out Access_Hashmaps_Type)
   is
      Children  : constant DOM.Core.Node_List
         := McKae.XML.XPath.XIA.XPath_Query
              (N     => Expr_Node,
               XPath => "./case");

      Node_Name : constant String
         := DOM.Core.Elements.Get_Attribute
              (Elem => Expr_Node,
               Name => "name");

      Case_Node : DOM.Core.Node;
   begin
      if DOM.Core.Nodes.Length (List => Children) /= 1 then
         raise Invalid_Expression with
            "Case-expression '"
            & DOM.Core.Elements.Get_Attribute
            (Elem => Expr_Node,
             Name => "name")
            & "' has"
            & DOM.Core.Nodes.Length (List => Children)'Image
            & " case-child nodes. Should have exactly one.";
      end if;
      Case_Node := DOM.Core.Nodes.Item (List  => Children,
                                        Index => 0);

      Evaluate_Case_Node
         (Case_Node     => Case_Node,
          Value_Of_Case => Value_Of_Case,
          Backtrace     => Backtrace,
          Node_Access   => Node_Access);

      case Value_Of_Case.Value_Type is
         when Boolean_Type =>
            if Log_Expansion_Values then
               Mulog.Log (Msg => "Expanding expression '"
                             & Node_Name
                             & "' with value '"
                             & Value_Of_Case.Bool_Value'Image
                             & "'");
            end if;
            Node_Access.Output_Boolean.Insert
               (Key      => Node_Name,
                New_Item => Value_Of_Case.Bool_Value);
         when Integer_Type =>
            if Log_Expansion_Values then
               Mulog.Log (Msg => "Expanding expression '"
                             & Node_Name
                             & "' with value '"
                             & Value_Of_Case.Int_Value'Image
                             & "'");
            end if;
            Node_Access.Output_Integer.Insert
               (Key      => Node_Name,
                New_Item => Value_Of_Case.Int_Value);
         when String_Type =>
            if Log_Expansion_Values then
               Mulog.Log (Msg => "Expanding expression '"
                             & Node_Name
                             & "' with value '"
                             & Value_Of_Case.String_Value.Element
                             & "'");
            end if;
            Node_Access.Output_String.Insert
               (Key      => Node_Name,
                New_Item => Value_Of_Case.String_Value.Element);
      end case;

   end Case_Expression_Evaluation;

   -------------------------------------------------------------------------

   procedure Evaluate_Case_Node
      (Case_Node     :        DOM.Core.Node;
       Value_Of_Case :    out Value_Type_Tuple;
       Backtrace     : in out String_Vector.Vector;
       Node_Access   : in out Access_Hashmaps_Type)
   is
      Children  : constant DOM.Core.Node_List
         := McKae.XML.XPath.XIA.XPath_Query
         (N     => Case_Node,
          XPath => "./when | ./others");
      Child_Type : Variable_Type;
      Return_Node : DOM.Core.Node;

      ----------------------------------------------------------------------

      --  Assign the value of Child to Child_Value.
      procedure Evaluate_When_Child
         (Child       :        DOM.Core.Node;
          Child_Value :    out Value_Type_Tuple;
          Backtrace   : in out String_Vector.Vector;
          Node_Access : in out Access_Hashmaps_Type);

      ----------------------------------------------------------------------

      procedure Evaluate_When_Child
         (Child       :        DOM.Core.Node;
          Child_Value :    out Value_Type_Tuple;
          Backtrace   : in out String_Vector.Vector;
          Node_Access : in out Access_Hashmaps_Type)
      is
         Child_Name : constant String
            := DOM.Core.Nodes.Node_Name (N => Child);
      begin
         if Child_Name = "case" then
            Evaluate_Case_Node
               (Case_Node     => Child,
                Value_Of_Case => Child_Value,
                Backtrace     => Backtrace,
                Node_Access   => Node_Access);

         elsif Child_Name = "variable" then
            Get_Value_Of_Reference
               (Ref_Name    => DOM.Core.Elements.Get_Attribute
                      (Elem    => Child,
                       Name    => "name"),
                Result      => Child_Value,
                Backtrace   => Backtrace,
                Node_Access => Node_Access);
         elsif Child_Name = "boolean"
            or Child_Name = "integer"
            or Child_Name = "string"
         then
            Get_Type_And_Value
               (Node           => Child,
                Type_And_Value => Child_Value);
         else
            raise Invalid_Expression with
               "When-Node inside of Case contains illegal node with name '"
               &  DOM.Core.Nodes.Node_Name (N => Child)
               & "'";
         end if;
      end Evaluate_When_Child;

   begin
      --  Assign the Return_Node to the when-child that matches.
      Evaluate_Case_Node_Frame (Case_Node   => Case_Node,
                                Return_Node => Return_Node,
                                Backtrace   => Backtrace,
                                Node_Access => Node_Access);
      if Return_Node = null then
         raise Invalid_Expression with
            "Found case-node in expression where none of the actuals "
            & "matches. Case-variable has name '"
            & DOM.Core.Elements.Get_Attribute (Elem => Case_Node,
                                               Name => "variable")
            & "'";
      end if;

      for I in 0 .. DOM.Core.Nodes.Length (List => Children) - 1 loop
         declare
            Child : constant DOM.Core.Node
               := DOM.Core.Nodes.Item (List  => Children,
                                       Index => I);
            Child_Children : constant DOM.Core.Node_List
               := McKae.XML.XPath.XIA.XPath_Query
               (N     => Child,
                XPath => "./*");
            Child_Child : DOM.Core.Node;
            Child_Value : Value_Type_Tuple;
         begin
            if DOM.Core.Nodes.Length (List => Child_Children) /= 1 then
               raise Invalid_Expression with
                  "When-Node inside of Case has"
                  & DOM.Core.Nodes.Length (List => Child_Children)'Image
                  & " child nodes. Should have one.";
            end if;
            Child_Child := DOM.Core.Nodes.Item (List  => Child_Children,
                                                Index => 0);
            Evaluate_When_Child
               (Child       => Child_Child,
                Child_Value => Child_Value,
                Backtrace   => Backtrace,
                Node_Access => Node_Access);

            if Child = Return_Node then
               Value_Of_Case :=  Child_Value;
            end if;

            --  Check that all options are of the same type.
            if I = 0 then
               Child_Type := Child_Value.Value_Type;
            elsif Child_Type /= Child_Value.Value_Type then
               raise Invalid_Expression with
                  "Case expression contains values of multiple types: '"
                  & Child_Type'Image
                  & "' and '"
                  & Child_Value.Value_Type'Image
                  & "'";
            end if;
         end;
      end loop;
   end Evaluate_Case_Node;

   -------------------------------------------------------------------------

   procedure Evaluate_Case_Node_Frame
      (Case_Node   :        DOM.Core.Node;
       Return_Node :    out DOM.Core.Node;
       Backtrace   : in out String_Vector.Vector;
       Node_Access : in out Access_Hashmaps_Type)
   is
      Case_Variable_Name : constant String
         := DOM.Core.Elements.Get_Attribute (Elem => Case_Node,
                                             Name => "variable");
      Case_Variable_Value : Value_Type_Tuple;
      Case_Children : constant DOM.Core.Node_List
         := McKae.XML.XPath.XIA.XPath_Query
         (N     => Case_Node,
          XPath => "./when | ./others");

      ----------------------------------------------------------------------

      --  Evaluate a when-option and write result to When_Variable_Value.
      procedure  Evaluate_When_Option
         (When_Node_RawValue  :        String;
          Case_Variable_Value :        Value_Type_Tuple;
          When_Variable_Value :    out Value_Type_Tuple;
          Backtrace           : in out String_Vector.Vector;
          Node_Access         : in out Access_Hashmaps_Type);

      ----------------------------------------------------------------------

      procedure  Evaluate_When_Option
         (When_Node_RawValue  :        String;
          Case_Variable_Value :        Value_Type_Tuple;
          When_Variable_Value :    out Value_Type_Tuple;
          Backtrace           : in out String_Vector.Vector;
          Node_Access         : in out Access_Hashmaps_Type)
      is
      begin
         --  Start evaluation of the given when-value.
         if When_Node_RawValue'Length > 0
            and then When_Node_RawValue (When_Node_RawValue'First) = '$'
         then
            declare
               Ref_Name : constant String
                  := When_Node_RawValue
                  (When_Node_RawValue'First + 1 .. When_Node_RawValue'Last);
            begin
               Get_Value_Of_Reference
                  (Ref_Name    => Ref_Name,
                   Result      => When_Variable_Value,
                   Backtrace   => Backtrace,
                   Node_Access => Node_Access);
            end;

            if When_Variable_Value.Value_Type /= Case_Variable_Value.Value_Type then
               raise  Invalid_Expression with
                  "Found case node where variable types do not match. "
                  & "Case-variable type is '"
                  & Case_Variable_Value.Value_Type'Image
                  & "' when-variable type is '"
                  & When_Variable_Value.Value_Type'Image
                  & "'";
            end if;
         else
            --  In this case we have a 'constant' without type.
            When_Variable_Value.Value_Type
               := Case_Variable_Value.Value_Type;

            begin
               if Case_Variable_Value.Value_Type = Boolean_Type then
                  When_Variable_Value.Bool_Value
                     := Boolean'Value (When_Node_RawValue);
               elsif Case_Variable_Value.Value_Type = Integer_Type then
                  When_Variable_Value.Int_Value
                     := Integer'Value (When_Node_RawValue);
               else
                  When_Variable_Value.String_Value
                     := String_Holder_Type.To_Holder (When_Node_RawValue);
               end if;
            exception
               when Constraint_Error =>
                  raise Invalid_Expression with
                     "Found when-node with value '"
                     & When_Node_RawValue
                     & "' which cannot be cast to "
                     & Case_Variable_Value.Value_Type'Image;
            end;
         end if;
      end Evaluate_When_Option;

   begin
      Return_Node := null;

      --  Get type and value of case-variable.
      if not Muxml.Utils.Has_Attribute (Node      => Case_Node,
                                        Attr_Name => "variable")
      then
         raise  Invalid_Expression with
            "Found case-node without 'variable' attribute";
      end if;

      Get_Value_Of_Reference
         (Ref_Name    => Case_Variable_Name,
          Result      => Case_Variable_Value,
          Backtrace   => Backtrace,
          Node_Access => Node_Access);

      --  Get type and value of when-variables.
      if DOM.Core.Nodes.Length (List => Case_Children) < 1 then
         raise  Invalid_Expression with
            "Found case-node without when-children";
      end if;

      for I in 0 .. DOM.Core.Nodes.Length (List => Case_Children) - 1 loop
         declare
            When_Node : constant DOM.Core.Node
               := DOM.Core.Nodes.Item (List  => Case_Children,
                                       Index => I);
            When_Node_RawValue : constant String
               := DOM.Core.Elements.Get_Attribute (Elem => When_Node,
                                                   Name => "value");
            When_Variable_Value : Value_Type_Tuple;
         begin
            if DOM.Core.Nodes.Node_Name (N => When_Node) = "others" then
               if I < DOM.Core.Nodes.Length (List => Case_Children) - 1 then
                  raise  Invalid_Expression with
                     "Found 'others'-node which is not the last child of 'case'";
               end if;
               if Return_Node = null then
                  Return_Node := When_Node;
               end if;
            elsif not Muxml.Utils.Has_Attribute
               (Node => When_Node,
                Attr_Name => "value")
            then
               raise Invalid_Expression with
                  "Found when-node without 'value' attribute";
            else
               Evaluate_When_Option
                  (When_Node_RawValue  => When_Node_RawValue,
                   Case_Variable_Value => Case_Variable_Value,
                   When_Variable_Value => When_Variable_Value,
                   Backtrace           => Backtrace,
                   Node_Access         => Node_Access);

               if "=" (L => When_Variable_Value, R => Case_Variable_Value) then
                  if Return_Node = null then
                     Return_Node := When_Node;
                  else
                     raise Invalid_Expression with
                        "Found case node where multiple values match. "
                        & "Case-variable value is '"
                        & To_String (VTT => Case_Variable_Value)
                        & "'";
                  end if;
               end if;
            end if;
         end;
      end loop;

   end Evaluate_Case_Node_Frame;

   -------------------------------------------------------------------------

   procedure Get_Type_And_Value
      (Node           :     DOM.Core.Node;
       Type_And_Value : out Value_Type_Tuple)
   is
      Node_Name : constant String
         := DOM.Core.Nodes.Node_Name (N => Node);
      Node_Value : constant String
         := DOM.Core.Elements.Get_Attribute (Elem => Node,
                                             Name => "value");
   begin
      if not Muxml.Utils.Has_Attribute (Node => Node, Attr_Name => "value") then
         raise Invalid_Expression with
            "Found node with name '"
            & Node_Name
            & "' without necessary 'value' attribute";
      elsif Node_Value'Length > 0
         and then Node_Value (Node_Value'First) = '$'
      then
         raise Invalid_Expression with
            "Node with name '"
            & Node_Name
            & "' must not have value starting with '$' within expressions";
      end if;

      if Node_Name = "boolean" then
         Type_And_Value.Value_Type := Boolean_Type;
         Type_And_Value.Bool_Value := Boolean'Value (Node_Value);
      elsif Node_Name = "integer" then
         Type_And_Value.Value_Type := Integer_Type;
         Type_And_Value.Int_Value := Integer'Value (Node_Value);
      elsif Node_Name = "string" then
         Type_And_Value.Value_Type := String_Type;
         Type_And_Value.String_Value
            := String_Holder_Type.To_Holder (Node_Value);
      else
         raise Invalid_Expression with
            "Cannot determine type and value of node with name '"
            & Node_Name
            & "'. Invalid node name.";
      end if;
   end Get_Type_And_Value;

   -------------------------------------------------------------------------

   --  Assign Result and set Found := 'True' if Node_Access.Output contains
   --  the key Name.
   --  Leave Result unchanged and set Found := 'False' otherwise.
   procedure Get_Value_If_Contained
      (Name        :     String;
       Result      : out Value_Type_Tuple;
       Found       : out Boolean;
       Node_Access :     Access_Hashmaps_Type);

   -------------------------------------------------------------------------

   procedure Get_Value_If_Contained
      (Name        :     String;
       Result      : out Value_Type_Tuple;
       Found       : out Boolean;
       Node_Access :     Access_Hashmaps_Type)
   is
   begin
      Found := False;
      if Node_Access.Output_Boolean.Contains (Name) then
         Found := True;
         Result.Value_Type := Boolean_Type;
         Result.Bool_Value := Node_Access.Output_Boolean (Name);
      elsif Node_Access.Output_Integer.Contains (Name) then
         Found := True;
         Result.Value_Type := Integer_Type;
         Result.Int_Value := Node_Access.Output_Integer (Name);
      elsif Node_Access.Output_String.Contains (Name) then
         Found := True;
         Result.Value_Type := String_Type;
         Result.String_Value := String_Holder_Type.To_Holder
            (Node_Access.Output_String (Name));
      end if;
   end Get_Value_If_Contained;

   -------------------------------------------------------------------------

   procedure Get_Value_Of_Reference
      (Ref_Name    :        String;
       Result      :    out Value_Type_Tuple;
       Backtrace   : in out String_Vector.Vector;
       Node_Access : in out Access_Hashmaps_Type)
   is
      Found : Boolean;
      Def_Node : DOM.Core.Node;

      ----------------------------------------------------------------------

   begin
      Get_Value_If_Contained (Name        => Ref_Name,
                              Result      => Result,
                              Found       => Found,
                              Node_Access => Node_Access);
      if not Found then
         Def_Node := Get_Defining_Node
            (Var_Name    => Ref_Name,
             Node_Access => Node_Access);
         Expand_Single_Node
            (Node        => Def_Node,
             Backtrace   => Backtrace,
             Node_Access => Node_Access);
         Get_Value_If_Contained (Name        => Ref_Name,
                                 Result      => Result,
                                 Found       => Found,
                                 Node_Access => Node_Access);
      end if;
      if not Found then
         raise Invalid_Expression with
            "Found Reference to non-existing variable with name '"
            & Ref_Name
            & "'";
      end if;
   end Get_Value_Of_Reference;

   -------------------------------------------------------------------------

   function Get_Value_Of_Reference_Debug
      (Ref_Name    : String;
       Node_Access : Access_Hashmaps_Type)
      return String
   is
      Result : Value_Type_Tuple;
      Found  : Boolean;
   begin
      Get_Value_If_Contained
         (Name        => Ref_Name,
          Result      => Result,
          Found       => Found,
          Node_Access => Node_Access);

      if not Found then
         return "";
      else
         return To_String (VTT => Result, No_Type => True);
      end if;
   end Get_Value_Of_Reference_Debug;

   -------------------------------------------------------------------------

   function To_String
      (VTT     : Value_Type_Tuple;
       No_Type : Boolean := False)
      return String
   is
      package ASU renames Ada.Strings.Unbounded;
      Output : ASU.Unbounded_String;
   begin
      if not No_Type then
         Output := ASU.To_Unbounded_String (VTT.Value_Type'Image & " ");
      end if;
      case VTT.Value_Type is
         when Boolean_Type =>
            ASU.Append (Source => Output,
                        New_Item => VTT.Bool_Value'Image);
         when Integer_Type =>
            ASU.Append (Source => Output,
                        New_Item => Ada.Strings.Fixed.Trim
                           (Source => VTT.Int_Value'Image,
                            Side   => Ada.Strings.Left));
         when String_Type =>
            ASU.Append (Source => Output,
                        New_Item => VTT.String_Value.Element);
      end case;
      return ASU.To_String (Output);
   end To_String;

end Mutools.Expressions.Case_Expression;
