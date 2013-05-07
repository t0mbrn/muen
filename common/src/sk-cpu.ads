--# inherit
--#    SK,
--#    X86_64;
package SK.CPU
is

   --  Restore CPU register values.
   procedure Restore_Registers (Regs : SK.CPU_Registers_Type);
   --# global
   --#    X86_64.State;
   --# derives
   --#    X86_64.State from *, Regs;
   pragma Inline_Always (Restore_Registers);

   --  Execute CPUID instruction.
   procedure CPUID
     (EAX : in out SK.Word32;
      EBX :    out SK.Word32;
      ECX : in out SK.Word32;
      EDX :    out SK.Word32);
   --# global
   --#    X86_64.State;
   --# derives
   --#    EAX, EBX, ECX, EDX from X86_64.State, EAX, ECX;
   pragma Inline_Always (CPUID);

   --  Halt the CPU.
   procedure Hlt;
   --# global
   --#    X86_64.State;
   --# derives
   --#    X86_64.State from *;
   pragma Inline_Always (Hlt);

   --  Load Interrupt Descriptor Table (IDT) register.
   procedure Lidt (Address : SK.Word64);
   --# global
   --#    in out X86_64.State;
   --# derives
   --#    X86_64.State from *, Address;
   pragma Inline_Always (Lidt);

   --  Panic.
   procedure Panic;
   --# global
   --#    X86_64.State;
   --# derives
   --#    X86_64.State from *;
   pragma Inline_Always (Panic);

   --  Return current value of CR0 register.
   function Get_CR0 return SK.Word64;
   --# global
   --#    X86_64.State;
   pragma Inline_Always (Get_CR0);

   --  Return current value of CR4 register.
   function Get_CR4 return SK.Word64;
   --# global
   --#    X86_64.State;
   pragma Inline_Always (Get_CR4);

   --  Return current value of CR3 register.
   function Get_CR3 return SK.Word64;
   --# global
   --#    X86_64.State;
   pragma Inline_Always (Get_CR3);

   --  Set value of CR4.
   procedure Set_CR4 (Value : SK.Word64);
   --# global
   --#    in out X86_64.State;
   --# derives
   --#    X86_64.State from *, Value;
   pragma Inline_Always (Set_CR4);

   --  Return current value of given model specific register.
   function Get_MSR64 (Register : SK.Word32) return SK.Word64;
   --# global
   --#    X86_64.State;
   pragma Inline_Always (Get_MSR64);

   --  Return value of given MSR as low/high doublewords.
   procedure Get_MSR
     (Register :     SK.Word32;
      Low      : out SK.Word32;
      High     : out SK.Word32);
   --# global
   --#    X86_64.State;
   --# derives
   --#    Low, High from X86_64.State, Register;
   pragma Inline_Always (Get_MSR);

   --  Write specified quadword to given MSR.
   procedure Write_MSR64
     (Register : SK.Word32;
      Value    : SK.Word64);
   --# global
   --#    in out X86_64.State;
   --# derives
   --#    X86_64.State from *, Register, Value;
   pragma Inline_Always (Write_MSR64);

   --  Write specified low/high doublewords to given MSR.
   procedure Write_MSR
     (Register : SK.Word32;
      Low      : SK.Word32;
      High     : SK.Word32);
   --# global
   --#    in out X86_64.State;
   --# derives
   --#    X86_64.State from *, Register, Low, High;
   pragma Inline_Always (Write_MSR);

   --  Return current RFLAGS.
   function Get_RFLAGS return SK.Word64;
   --# global
   --#    X86_64.State;
   pragma Inline_Always (Get_RFLAGS);

   --  Set CPU RSP and RBP registers to given address.
   procedure Set_Stack (Address : SK.Word64);
   --# global
   --#    in out X86_64.State;
   --# derives
   --#    X86_64.State from *, Address;
   pragma Inline_Always (Set_Stack);

   --  Enter VMX operation.
   procedure VMXON
     (Region  :     SK.Word64;
      Success : out Boolean);
   --# global
   --#    in out X86_64.State;
   --# derives
   --#    X86_64.State from *, Region &
   --#    Success      from X86_64.State, Region;
   pragma Inline_Always (VMXON);

   --  Launch VM designated by current VMCS.
   procedure VMLAUNCH;
   --# global
   --#    in out X86_64.State;
   --# derives
   --#    X86_64.State from *;
   pragma Inline_Always (VMLAUNCH);

   --  Resume VM designated by current VMCS.
   procedure VMRESUME;
   --# global
   --#    in out X86_64.State;
   --# derives
   --#    X86_64.State from *;
   pragma Inline_Always (VMRESUME);

   procedure VMCLEAR
     (Region  :     SK.Word64;
      Success : out Boolean);
   --# global
   --#    in out X86_64.State;
   --# derives
   --#    X86_64.State from *, Region &
   --#    Success      from X86_64.State, Region;
   pragma Inline_Always (VMCLEAR);

   procedure VMPTRLD
     (Region  :     SK.Word64;
      Success : out Boolean);
   --# global
   --#    in out X86_64.State;
   --# derives
   --#    X86_64.State from *, Region &
   --#    Success      from X86_64.State, Region;
   pragma Inline_Always (VMPTRLD);

   procedure VMREAD
     (Field   :     SK.Word64;
      Value   : out SK.Word64;
      Success : out Boolean);
   --# global
   --#    X86_64.State;
   --# derives
   --#    Value, Success from X86_64.State, Field;
   pragma Inline_Always (VMREAD);

   procedure VMWRITE
     (Field   :     SK.Word64;
      Value   :     SK.Word64;
      Success : out Boolean);
   --# global
   --#    in out X86_64.State;
   --# derives
   --#    X86_64.State, Success from X86_64.State, Field, Value;
   pragma Inline_Always (VMWRITE);

end SK.CPU;
