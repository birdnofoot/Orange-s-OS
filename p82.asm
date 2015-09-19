; ==========================================
; pmtest8.asm
; 编译方法：nasm pmtest8.asm -o pmtest8.com
; ==========================================

%include	"pm.inc"	; 常量, 宏, 以及一些说明

PageDirBase0		equ	200000h	; 页目录开始地址:	2M
PageTblBase0		equ	201000h	; 页表开始地址:		2M +  4K
PageDirBase1		equ	210000h	; 页目录开始地址:	2M + 64K
PageTblBase1		equ	211000h	; 页表开始地址:		2M + 64K + 4K == 0010 0001 0000 0100 0000 0000

LinearAddrDemo		equ	00401000h
ProcFoo				equ	00401000h
ProcBar				equ	00501000h
ProcPagingDemo		equ	00301000h

org	07C00h
	jmp	LABEL_BEGIN

[SECTION .gdt]
;DA_DRW EQU	92h	
;DA_CR EQU 9Ah	;
;DA_32 EQU 4000h	
;DA_LIMIT_4K EQU 8000h
; GDT
;                           段基址,       段界限, 属性
LABEL_GDT:          Descriptor 0,              0, 0                      ; 空描述符
LABEL_DESC_NORMAL:  Descriptor 0,         0ffffh, DA_DRW                 ; Normal 描述符

; [add]
LABEL_DESC_FLAT_C:  Descriptor 0,        0fffffh, DA_CR|DA_32|DA_LIMIT_4K; 0~4G [ 9Ah | 4000h | 8000h
; [add]
LABEL_DESC_FLAT_RW: Descriptor 0,        0fffffh, DA_DRW|DA_LIMIT_4K     ; 0~4G [ 92h | 8000h

LABEL_DESC_CODE32:  Descriptor 0, SegCode32Len-1, DA_CR|DA_32            ; 非一致代码段, 32
LABEL_DESC_CODE16:  Descriptor 0,         0ffffh, DA_C                   ; 非一致代码段, 16
LABEL_DESC_DATA:    Descriptor 0,      DataLen-1, DA_DRW                 ; Data
LABEL_DESC_STACK:   Descriptor 0,     TopOfStack, DA_DRWA|DA_32          ; Stack, 32 位
LABEL_DESC_VIDEO:   Descriptor 0B8000h,   0ffffh, DA_DRW                 ; 显存首地址
; GDT 结束

GdtLen		equ	$ - LABEL_GDT	; GDT长度
GdtPtr		dw	GdtLen - 1	; GDT界限
		dd	0		; GDT基地址

; GDT 选择子
SelectorNormal		equ	LABEL_DESC_NORMAL	- LABEL_GDT
SelectorFlatC		equ	LABEL_DESC_FLAT_C	- LABEL_GDT
SelectorFlatRW		equ	LABEL_DESC_FLAT_RW	- LABEL_GDT
SelectorCode32		equ	LABEL_DESC_CODE32	- LABEL_GDT
SelectorCode16		equ	LABEL_DESC_CODE16	- LABEL_GDT
SelectorData		equ	LABEL_DESC_DATA		- LABEL_GDT
SelectorStack		equ	LABEL_DESC_STACK	- LABEL_GDT
SelectorVideo		equ	LABEL_DESC_VIDEO	- LABEL_GDT
; END of [SECTION .gdt]

[SECTION .data1]	 ; 数据段
ALIGN	32
[BITS	32]
LABEL_DATA:
; 实模式下使用这些符号
; 字符串
_szPMMessage:			db	"In Protect Mode now. ^-^", 0Ah, 0Ah, 0	; 进入保护模式后显示此字符串
_szMemChkTitle:			db	"BaseAddrL BaseAddrH LengthLow LengthHigh   Type", 0Ah, 0	; 进入保护模式后显示此字符串
_szRAMSize			db	"RAM size:", 0
_szReturn			db	0Ah, 0
; 变量
_wSPValueInRealMode		dw	0
_dwMCRNumber:			dd	0	; Memory Check Result
_dwDispPos:			dd	(80 * 6 + 0) * 2	; 屏幕第 6 行, 第 0 列。
_dwMemSize:			dd	0
_ARDStruct:			; Address Range Descriptor Structure
	_dwBaseAddrLow:		dd	0
	_dwBaseAddrHigh:	dd	0
	_dwLengthLow:		dd	0
	_dwLengthHigh:		dd	0
	_dwType:		dd	0
_PageTableNumber		dd	0

_MemChkBuf:	times	256	db	0

; 保护模式下使用这些符号
szPMMessage		equ	_szPMMessage	- $$
szMemChkTitle		equ	_szMemChkTitle	- $$
szRAMSize		equ	_szRAMSize	- $$
szReturn		equ	_szReturn	- $$
dwDispPos		equ	_dwDispPos	- $$
dwMemSize		equ	_dwMemSize	- $$
dwMCRNumber		equ	_dwMCRNumber	- $$
ARDStruct		equ	_ARDStruct	- $$
	dwBaseAddrLow	equ	_dwBaseAddrLow	- $$
	dwBaseAddrHigh	equ	_dwBaseAddrHigh	- $$
	dwLengthLow	equ	_dwLengthLow	- $$
	dwLengthHigh	equ	_dwLengthHigh	- $$
	dwType		equ	_dwType		- $$
MemChkBuf		equ	_MemChkBuf	- $$
PageTableNumber		equ	_PageTableNumber- $$

DataLen			equ	$ - LABEL_DATA
; END of [SECTION .data1]


; 全局堆栈段
[SECTION .gs]
ALIGN	32
[BITS	32]
LABEL_STACK:
	times 512 db 0

TopOfStack	equ	$ - LABEL_STACK - 1

; END of [SECTION .gs]


[SECTION .s16]
[BITS	16]
LABEL_BEGIN:
	mov	ax, cs
	mov	ds, ax
	mov	es, ax
	mov	ss, ax
	mov	sp, 0100h

	mov	[LABEL_GO_BACK_TO_REAL+3], ax
	mov	[_wSPValueInRealMode], sp

	; 得到内存数
	mov	ebx, 0
	mov	di, _MemChkBuf
.loop:
	mov	eax, 0E820h
	mov	ecx, 20
	mov	edx, 0534D4150h
	int	15h
	jc	LABEL_MEM_CHK_FAIL
	add	di, 20
	inc	dword [_dwMCRNumber]
	cmp	ebx, 0
	jne	.loop
	jmp	LABEL_MEM_CHK_OK
LABEL_MEM_CHK_FAIL:
	mov	dword [_dwMCRNumber], 0
LABEL_MEM_CHK_OK:

	; 初始化 16 位代码段描述符
	mov	ax, cs
	movzx	eax, ax
	shl	eax, 4
	add	eax, LABEL_SEG_CODE16
	mov	word [LABEL_DESC_CODE16 + 2], ax
	shr	eax, 16
	mov	byte [LABEL_DESC_CODE16 + 4], al
	mov	byte [LABEL_DESC_CODE16 + 7], ah

	; 初始化 32 位代码段描述符
	xor	eax, eax
	mov	ax, cs
	shl	eax, 4
	add	eax, LABEL_SEG_CODE32
	mov	word [LABEL_DESC_CODE32 + 2], ax
	shr	eax, 16
	mov	byte [LABEL_DESC_CODE32 + 4], al
	mov	byte [LABEL_DESC_CODE32 + 7], ah

	; 初始化数据段描述符
	xor	eax, eax
	mov	ax, ds
	shl	eax, 4
	add	eax, LABEL_DATA
	mov	word [LABEL_DESC_DATA + 2], ax
	shr	eax, 16
	mov	byte [LABEL_DESC_DATA + 4], al
	mov	byte [LABEL_DESC_DATA + 7], ah

	; 初始化堆栈段描述符
	xor	eax, eax
	mov	ax, ds
	shl	eax, 4
	add	eax, LABEL_STACK
	mov	word [LABEL_DESC_STACK + 2], ax
	shr	eax, 16
	mov	byte [LABEL_DESC_STACK + 4], al
	mov	byte [LABEL_DESC_STACK + 7], ah

	; 为加载 GDTR 作准备
	xor	eax, eax
	mov	ax, ds
	shl	eax, 4
	add	eax, LABEL_GDT		; eax <- gdt 基地址
	mov	dword [GdtPtr + 2], eax	; [GdtPtr + 2] <- gdt 基地址

	; 加载 GDTR
	lgdt	[GdtPtr]

	; 关中断
	cli

	; 打开地址线A20
	in	al, 92h
	or	al, 00000010b
	out	92h, al

	; 准备切换到保护模式
	mov	eax, cr0
	or	eax, 1
	mov	cr0, eax

	; 真正进入保护模式
	jmp	dword SelectorCode32:0	; 执行这一句会把 SelectorCode32 装入 cs, 并跳转到 Code32Selector:0  处

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

LABEL_REAL_ENTRY:		; 从保护模式跳回到实模式就到了这里
	mov	ax, cs
	mov	ds, ax
	mov	es, ax
	mov	ss, ax

	mov	sp, [_wSPValueInRealMode]

	in	al, 92h		; ┓
	and	al, 11111101b	; ┣ 关闭 A20 地址线
	out	92h, al		; ┛

	sti			; 开中断

	mov	ax, 4c00h	; ┓
	int	21h		; ┛回到 DOS
; END of [SECTION .s16]


[SECTION .s32]; 32 位代码段. 由实模式跳入.
[BITS	32]

LABEL_SEG_CODE32:
	mov	ax, SelectorData
	mov	ds, ax			; 数据段选择子
	mov	es, ax
	mov	ax, SelectorVideo
	mov	gs, ax			; 视频段选择子

	mov	ax, SelectorStack
	mov	ss, ax			; 堆栈段选择子

	mov	esp, TopOfStack


	; 下面显示一个字符串
	push	szPMMessage
	call	DispStr
	add	esp, 4

	push	szMemChkTitle
	call	DispStr
	add	esp, 4

	; call	DispMemSize		; 显示内存信息

	call	PagingDemo		; 演示改变页目录的效果

	; 到此停止
	jmp	SelectorCode16:0

; 启动分页机制 --------------------------------------------------------------
SetupPaging:
	; 根据内存大小计算应初始化多少PDE以及多少页表
	xor	edx, edx
	mov	eax, [dwMemSize]
	mov	ebx, 400000h	; 400000h = 4M = 4096 * 1024, 一个页表对应的内存大小
	div	ebx
	mov	ecx, eax	; 此时 ecx 为页表的个数，也即 PDE 应该的个数
	test	edx, edx
	jz	.no_remainder
	inc	ecx		; 如果余数不为 0 就需增加一个页表
.no_remainder:
	mov	[PageTableNumber], ecx	; 暂存页表个数

	; 为简化处理, 所有线性地址对应相等的物理地址. 并且不考虑内存空洞.

	; 首先初始化页目录
	mov	ax, SelectorFlatRW		
	mov	es, ax					; es是目的基地址
	mov	edi, PageDirBase0	; 此段首地址为 PageDirBase0 == 20000h
	xor	eax, eax
	mov	eax, PageTblBase0 | PG_P  | PG_USU | PG_RWW ; PageTblBase0=201000h , result = 201111h
	; PG_P		EQU	1	; 页存在属性位
	; PG_RWR		EQU	0	; R/W 属性位值, 读/执行
	; PG_RWW		EQU	2	; R/W 属性位值, 读/写/执行
	; PG_USS		EQU	0	; U/S 属性位值, 系统级
	; PG_USU		EQU	4	; U/S 属性位值, 用户级
	; | PG_P  | PG_USU | PG_RWW == 0111h
	
.1:
	stosd 				; stosb, stosw, stosd 把al/ ax/ eax的内容存储到 es:edi 指向的内存单元中, 该指令执行后，edi自增1,2,4
	add	eax, 4096		; 为了简化, 所有页表在内存中是连续的.
	loop	.1

	; 再初始化所有页表
	mov	eax, [PageTableNumber]	; 页表个数
	mov	ebx, 1024		; 每个页表 1024 个 PTE
	mul	ebx
	mov	ecx, eax		; PTE个数 = 页表个数 * 1024
	mov	edi, PageTblBase0	; 此段首地址为 PageTblBase0
	xor	eax, eax
	mov	eax, PG_P  | PG_USU | PG_RWW ; 0111
.2:
	stosd
	add	eax, 4096		; 每一页指向 4K 的空间
	loop	.2

	mov	eax, PageDirBase0
	mov	cr3, eax
	mov	eax, cr0
	or	eax, 80000000h
	mov	cr0, eax
	jmp	short .3
.3:
	nop

	ret
; 分页机制启动完毕 ----------------------------------------------------------


; 测试分页机制 --------------------------------------------------------------
PagingDemo:
	mov	ax, cs
	mov	ds, ax
	; LABEL_DESC_FLAT_RW: Descriptor 0, 0fffffh, DA_DRW|DA_LIMIT_4K
	; SelectorFlatRW equ LABEL_DESC_FLAT_RW	- LABEL_GDT 
	mov	ax, SelectorFlatRW  
	mov	es, ax

; foo:
; OffsetFoo		equ	foo - $$    ; $$ == LABEL_SEG_CODE32 
; 	mov	ah, 0Ch			; 0000: 黑底    1100: 红字
;	mov	al, 'F'
;	mov	[gs:((80 * 17 + 0) * 2)], ax	; 屏幕第 17 行, 第 0 列。
;	mov	al, 'o'
;	mov	[gs:((80 * 17 + 1) * 2)], ax	; 屏幕第 17 行, 第 1 列。
;	mov	[gs:((80 * 17 + 2) * 2)], ax	; 屏幕第 17 行, 第 2 列。
;	ret
; LenFoo			equ	$ - foo

	push	LenFoo	   ; 拷贝代码的长度
	push	OffsetFoo  ;  拷贝代码的源地址
	push	ProcFoo    ; ProcFoo equ 00401000h ,拷贝代码的目的地址
	call	MemCpy     ; 将偏移地址为 OffsetFoo （ foo 基地址）处的内容拷贝 LenFoo 个字节到（即全部） ProcFoo 
					   ; 注意 es = LABEL_DESC_FLAT_RW 存储的基地址0 ; ds = 32位代码段基地址
	add		esp, 12

; bar:
; OffsetBar		equ	bar - $$
;	mov	ah, 0Ch			; 0000: 黑底    1100: 红字
;	mov	al, 'B'
;	mov	[gs:((80 * 18 + 0) * 2)], ax	; 屏幕第 18 行, 第 0 列。
;	mov	al, 'a'
;	mov	[gs:((80 * 18 + 1) * 2)], ax	; 屏幕第 18 行, 第 1 列。
;	mov	al, 'r'
;	mov	[gs:((80 * 18 + 2) * 2)], ax	; 屏幕第 18 行, 第 2 列。
;	ret
; LenBar equ	$ - bar

	push	LenBar		; 拷贝代码的长度
	push	OffsetBar	; 拷贝代码的源地址
	push	ProcBar		; ProcBar equ 00501000h  ,拷贝代码的目的地址
	call	MemCpy		; 将偏移地址为OffsetBar（bar基地址）处的内容拷贝 LenBar 个字节到（即全部）ProcBar
						; 注意 es = LABEL_DESC_FLAT_RW 存储的基地址0 ; ds = 32位代码段基地址
	add	esp, 12

; PagingDemoProc:
; OffsetPagingDemoProc	equ	PagingDemoProc - $$
;	mov	eax, LinearAddrDemo    ; LinearAddrDemo	equ	00401000h
;	call	eax				   ; ProcFoo == 00401000h ，跳转到 00401000h 去执行，即打印 'FOO' ；
;	retf
; LenPagingDemoAll	equ	$ - PagingDemoProc

	push	LenPagingDemoAll	; 拷贝代码的长度
	push	OffsetPagingDemoProc ; 拷贝代码的源地址
	push	ProcPagingDemo		;ProcPagingDemo equ	00301000h， ; 拷贝代码的目的地址
	call	MemCpy				; 将偏移地址为 OffsetPagingDemoProc （ PagingDemoProc 基地址）处的内容拷贝 LenPagingDemoAll 个字节到（即全部） ProcPagingDemo
								; 注意 es = LABEL_DESC_FLAT_RW 存储的基地址0 ; ds = 32位代码段基地址
	add	esp, 12

	mov	ax, SelectorData
	mov	ds, ax			; 数据段选择子
	mov	es, ax

	call	SetupPaging		; 启动分页

; SelectorFlatC equ LABEL_DESC_FLAT_C	- LABEL_GDT
; LABEL_DESC_FLAT_C:  Descriptor 0, 0fffffh, DA_CR|DA_32|DA_LIMIT_4K; 0~4G [ 9Ah | 4000h | 8000h
	call	SelectorFlatC:ProcPagingDemo ; 打印 'FOO' 
	
	call	PSwitch			; 切换页目录，改变地址映射关系 ，将 LinearAddrDemo	equ	00401000h 改为:LinearAddrDemo	equ	00401000h
	call	SelectorFlatC:ProcPagingDemo

	ret
; ---------------------------------------------------------------------------


; 切换页表 ------------------------------------------------------------------
PSwitch:
	; 初始化页目录
	mov	ax, SelectorFlatRW		; SelectorFlatRW equ	LABEL_DESC_FLAT_RW	- LABEL_GDT
	mov	es, ax					
	mov	edi, PageDirBase1	; 此段首地址为 PageDirBase1; PageDirBase1 equ 210000h	; 页目录开始地址:	2M + 64K
	xor	eax, eax
	mov	eax, PageTblBase1 | PG_P  | PG_USU | PG_RWW		; PageTblBase1 equ 211000h ; result = 211111h
	mov	ecx, [PageTableNumber]
.1:
	stosd
	add	eax, 4096		; 为了简化, 所有页表在内存中是连续的.
	loop	.1

	; 再初始化所有页表
	mov	eax, [PageTableNumber]	; 页表个数
	mov	ebx, 1024		; 每个页表 1024 个 PTE
	mul	ebx
	mov	ecx, eax		; PTE个数 = 页表个数 * 1024
	mov	edi, PageTblBase1	; 此段首地址为 PageTblBase1 = 210000h
	xor	eax, eax
	mov	eax, PG_P  | PG_USU | PG_RWW    ; PG_P  | PG_USU | PG_RWW = 0111h
.2:
	stosd
	add	eax, 4096		; 每一页指向 4K 的空间
	loop	.2

	; 在此假设内存是大于 8M 的（注意，这里的地址是 32 bits）
	; 我们看 00401000 = [00 0000 0001] [00 0000 0001] [0000 0000 0000]
	mov	eax, LinearAddrDemo		; LinearAddrDemo equ 00401000h 4M + 4k (00401000 -> eax)
	shr	eax, 22			; 右移22位，得到高10位[bit31~22]=0000 0000 01 作为result= {0,[bit9~0]}，显然页目录项索引
	mov	ebx, 4096
	mul	ebx				;左移12位，低位补0，得到高10位[bit31~22]=0000 0000 01  作为result= {0,[bit21~12] ,0}
						; 执行后，result[bit21~12]=1 存储着 页目录项值; 即解析出 00401000h 的页目录项索引1（页表基地址的索引）
	mov	ecx, eax		; ecx = 0,bit21[LinearAddrDemo的bit31~22]bit12,0 = 0,bit21[0000000001]bit12,0
						
	mov	eax, LinearAddrDemo
	shr	eax, 12			; 右移12位，得到高20位(bit31~12) 作为result[bit19~0]=00401h;
	and	eax, 03FFh	 	; 0011 1111 1111b (10 bits);得到 LinearAddrDemo[bit21~12] 作为 result[bit9~0]=00 0000 0001
	mov	ebx, 4
	mul	ebx				; 左移2位,得到result[bit11~2]=00 0000 0001 >> result = 0,bit11[0000000001]bit2, 0
						; 执行后，eax[bit11~2] 存储着 页表项的值 ; 即解析出 00401000h 的页表项索引（物理页基地址的索引）
	add	eax, ecx		; eax = 0,bit11[LinearAddrDemo的bit21~12]bit2,0
						; 加法后，形成了 result 的 bit21~2(高10位-页目录项索引，低10-页表项索引)
	add	eax, PageTblBase1		; PageTblBase1 = 210000h，页表基地址
	mov	dword [es:eax], ProcBar | PG_P | PG_USU | PG_RWW		;ProcBar equ 00501000h ,es作为目的基地址
	; 以上指令执行后，LinearAddrDemo将不再对应 ProcFoo(00401000h) 而是对应ProcBar(00501000h)

	; PageDirBase1		equ	210000h	; 页目录开始地址:	2M + 64K
	mov	eax, PageDirBase1
	mov	cr3, eax
	jmp	short .3
.3:
	nop

	ret
; ---------------------------------------------------------------------------



PagingDemoProc:
OffsetPagingDemoProc	equ	PagingDemoProc - $$
	mov	eax, LinearAddrDemo
	call	eax
	retf
LenPagingDemoAll	equ	$ - PagingDemoProc

foo:
OffsetFoo		equ	foo - $$
	mov	ah, 0Ch			; 0000: 黑底    1100: 红字
	mov	al, 'F'
	mov	[gs:((80 * 17 + 0) * 2)], ax	; 屏幕第 17 行, 第 0 列。
	mov	al, 'o'
	mov	[gs:((80 * 17 + 1) * 2)], ax	; 屏幕第 17 行, 第 1 列。
	mov	[gs:((80 * 17 + 2) * 2)], ax	; 屏幕第 17 行, 第 2 列。
	ret
LenFoo			equ	$ - foo

bar:
OffsetBar		equ	bar - $$
	mov	ah, 0Ch			; 0000: 黑底    1100: 红字
	mov	al, 'B'
	mov	[gs:((80 * 18 + 0) * 2)], ax	; 屏幕第 18 行, 第 0 列。
	mov	al, 'a'
	mov	[gs:((80 * 18 + 1) * 2)], ax	; 屏幕第 18 行, 第 1 列。
	mov	al, 'r'
	mov	[gs:((80 * 18 + 2) * 2)], ax	; 屏幕第 18 行, 第 2 列。
	ret
LenBar			equ	$ - bar


; 显示内存信息 --------------------------------------------------------------
DispMemSize:
	push	esi
	push	edi
	push	ecx

	mov	esi, MemChkBuf ; _MemChkBuf:	times	256	db	0 , _dwMCRNumber: dd	0	; Memory Check Result
	mov	ecx, [dwMCRNumber]	;for(int i=0;i<[MCRNumber];i++) // 每次得到一个ARDS(Address Range Descriptor Structure)结构
.loop:					;{
	mov	edx, 5			;	for(int j=0;j<5;j++)	// 每次得到一个ARDS中的成员，共5个成员
	mov	edi, ARDStruct		;	{			// 依次显示：BaseAddrLow，BaseAddrHigh，LengthLow，LengthHigh，Type
.1:					;
	push	dword [esi]		;
	call	DispInt			;		DispInt(MemChkBuf[j*4]); // 显示一个成员
	pop	eax			;
	stosd				;		ARDStruct[j*4] = MemChkBuf[j*4];
	add	esi, 4			;
	dec	edx			;
	cmp	edx, 0			;
	jnz	.1			;	}
	call	DispReturn		;	printf("\n");
	cmp	dword [dwType], 1	;	if(Type == AddressRangeMemory) // AddressRangeMemory : 1, AddressRangeReserved : 2
	jne	.2			;	{
	mov	eax, [dwBaseAddrLow]	;
	add	eax, [dwLengthLow]	;
	cmp	eax, [dwMemSize]	;		if(BaseAddrLow + LengthLow > MemSize)
	jb	.2			;
	mov	[dwMemSize], eax	;			MemSize = BaseAddrLow + LengthLow;
.2:					;	}
	loop	.loop			;}
					;
	call	DispReturn		;printf("\n");
	push	szRAMSize		;
	call	DispStr			;printf("RAM size:");
	add	esp, 4			;
					;
	push	dword [dwMemSize]	;
	call	DispInt			;DispInt(MemSize);
	add	esp, 4			;

	pop	ecx
	pop	edi
	pop	esi
	ret
; ---------------------------------------------------------------------------

%include	"lib.inc"	; 库函数

SegCode32Len	equ	$ - LABEL_SEG_CODE32
; END of [SECTION .s32]


; 16 位代码段. 由 32 位代码段跳入, 跳出后到实模式
[SECTION .s16code]
ALIGN	32
[BITS	16]
LABEL_SEG_CODE16:
	; 跳回实模式:
	mov	ax, SelectorNormal 
	mov	ds, ax
	mov	es, ax
	mov	fs, ax
	mov	gs, ax
	mov	ss, ax

	mov	eax, cr0
	and     eax, 7FFFFFFEh          ; PE=0, PG=0
	mov	cr0, eax

LABEL_GO_BACK_TO_REAL:
	jmp	0:LABEL_REAL_ENTRY	; 段地址会在程序开始处被设置成正确的值

Code16Len	equ	$ - LABEL_SEG_CODE16

; END of [SECTION .s16code]