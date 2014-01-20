/*
 *  Copyright (C) 2013  Reto Buerki <reet@codelabs.ch>
 *  Copyright (C) 2013  Adrian-Ken Rueegsegger <ken@codelabs.ch>
 *
 *  This program is free software: you can redistribute it and/or modify
 *  it under the terms of the GNU General Public License as published by
 *  the Free Software Foundation, either version 3 of the License, or
 *  (at your option) any later version.
 *
 *  This program is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *  GNU General Public License for more details.
 *
 *  You should have received a copy of the GNU General Public License
 *  along with this program.  If not, see <http://www.gnu.org/licenses/>.
 */

#define CPU_COUNT     __cpu_count__
#define KERNEL_STACK  0x__stack_addr__
#define KERNEL_PML4   0x__kpml4_addr__
#define PERCPU_STORE  0x__cpu_store_addr__
#define SUBJECT_COUNT __subj_count__
#define VMXON_ADDRESS 0x__vmxon_addr__
#define VMCS_ADDRESS  0x__vmcs_addr__
#define PAT_HIGH      0x00000006
#define PAT_LOW       0x05040100
