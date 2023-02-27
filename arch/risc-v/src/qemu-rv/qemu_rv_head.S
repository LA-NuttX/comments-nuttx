/****************************************************************************
 * arch/risc-v/src/qemu-rv/qemu_rv_head.S
 *
 * Licensed to the Apache Software Foundation (ASF) under one or more
 * contributor license agreements.  See the NOTICE file distributed with
 * this work for additional information regarding copyright ownership.  The
 * ASF licenses this file to you under the Apache License, Version 2.0 (the
 * "License"); you may not use this file except in compliance with the
 * License.  You may obtain a copy of the License at
 *
 *   http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS, WITHOUT
 * WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.  See the
 * License for the specific language governing permissions and limitations
 * under the License.
 *
 ****************************************************************************/

/****************************************************************************
 * Included Files
 ****************************************************************************/

#include <nuttx/config.h>

#include <arch/arch.h>
#include <arch/irq.h>
# 引用了nuttx/arch/risc-v/include文件夹下

#include "chip.h"
# 引用了nuttx/arch/risc-v/src/qemu-rv/chip.h
#include "riscv_internal.h"
# 引用了nuttx/arch/risc-v/src/common/riscv_internal.h

/****************************************************************************
 * Public Symbols
 ****************************************************************************/

  /* Exported Symbols */

  .section .text
  .global __start

__start:

  /* Load mhartid (cpuid) */

  csrr a0, mhartid

  /* Set stack pointer to the idle thread stack */
//sp进入C环境后，编译器会根据abi动态调整sp的值，见abi
  bnez a0, 1f
  la   sp, QEMU_RV_IDLESTACK_TOP//0号核设置成QEMU_RV_IDLESTACK_TOP
  j    2f
1:

  /* Load the number of CPUs that the kernel supports */

#ifdef CONFIG_SMP
  li   t1, CONFIG_SMP_NCPUS
#else
  li   t1, 1
#endif

  /* If a0 (mhartid) >= t1 (the number of CPUs), stop here */

  blt  a0, t1, 3f
  csrw mie, zero
  wfi

3:
  /* To get g_cpu_basestack[mhartid], must get g_cpu_basestack first */

  la   t0, g_cpu_basestack

  /* Offset = pointer width * hart id */
  /* t1是cpu数量，a0是当前hardit */
#ifdef CONFIG_ARCH_RV32
  slli t1, a0, 2
#else
  slli t1, a0, 3
  /*t1=a0<<3 */
#endif
  add  t0, t0, t1

  /* Load idle stack base to sp */

  REGLOAD sp, 0(t0)
//取得当前核的stack base
  /*
   * sp (stack top) = sp + idle stack size - XCPTCONTEXT_SIZE
   * 
   * Note: Reserve some space used by up_initial_state since we are already
   * running and using the per CPU idle stack.
   */

  li   t0, STACK_ALIGN_UP(CONFIG_IDLETHREAD_STACKSIZE - XCPTCONTEXT_SIZE)
  add  sp, sp, t0
//设置当前核的stack top
2:

  /* Disable all interrupts (i.e. timer, external) in mie */

	csrw	mie, zero

  la   t0, __trap_vec
  csrw mtvec, t0

  /* Jump to qemu_rv_start */

  jal  x1, qemu_rv_start

  /* We shouldn't return from _start */

  .global _init
  .global _fini

_init:
_fini:

  /* These don't have to do anything since we use init_array/fini_array. */

  ret
