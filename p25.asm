; ==========================================
; pmtest1.asm
; ���뷽����nasm pmtest1.asm -o pmtest1.bin
; ==========================================

%include	"pm.inc"	; ����, ��, �Լ�һЩ˵��

org	0100h
	jmp	LABEL_BEGIN

[SECTION .gdt]
; GDT
;                              �λ�ַ,       �ν���     , ����
LABEL_GDT:	   Descriptor       0,                0, 0           ; ��������
LABEL_DESC_CODE32: Descriptor       0, SegCode32Len - 1, DA_C + DA_32; ��һ�´����
LABEL_DESC_VIDEO:  Descriptor 0B8000h,           0ffffh, DA_DRW	     ; �Դ��׵�ַ ;Mine��0B8000h�����Դ����ַ��
; GDT ����

GdtLen		equ	$ - LABEL_GDT	; GDT���ȣ�Mine��ʲô������==������LABEL_GDTΪ��ˣ������һȺ���У�GdtLen��¼����������ĳ��ȡ�
GdtPtr		dw	GdtLen - 1	; GDT����
		dd	0		; GDT����ַ

; Mine���ҵĸ�����ѡ���Ӳ�����ȫ��ͬ�ڻ�ַƫ�Ƶ�ַ���μ�P32��
; GDT ѡ���ӣ�Mine��ѡ����==��Ӧ�����������е�ַ�����ȫ�����������ƫ�ƣ�ȫ�����������Ǳ�ͷ������Ϊ��ˡ�
SelectorCode32		equ	LABEL_DESC_CODE32	- LABEL_GDT
SelectorVideo		equ	LABEL_DESC_VIDEO	- LABEL_GDT
; END of [SECTION .gdt]

[SECTION .s16]    ; Mine��Ϊ��ʵģʽ��ת������ģʽ������׼��������
[BITS	16]
LABEL_BEGIN:
	mov	ax, cs
	mov	ds, ax	
	mov	es, ax
	mov	ss, ax
	mov	sp, 0100h

	; ��ʼ�� 32 λ�������������Mine��1.��LABEL_SEG_CODE32������ʱ���ڴ��ַ��¼�ڴ������������; 
									; 2.����� cs ��ֵҲ����LABEL_DESC_CODE32�������ˡ�
	xor	eax, eax
	mov	ax, cs
	shl	eax, 4
	add	eax, LABEL_SEG_CODE32
	mov	word [LABEL_DESC_CODE32 + 2], ax
	shr	eax, 16
	mov	byte [LABEL_DESC_CODE32 + 4], al
	mov	byte [LABEL_DESC_CODE32 + 7], ah

	; Ϊ���� GDTR ��׼����Mine����ȫ�������������ص��ڴ��ַ��¼��GdtPtr�С�
	xor	eax, eax
	mov	ax, ds
	shl	eax, 4
	add	eax, LABEL_GDT		; eax <- gdt ����ַ
	mov	dword [GdtPtr + 2], eax	; [GdtPtr + 2] <- gdt ����ַ

	; ���� GDTR
	lgdt	[GdtPtr]    ; Mine����GdtPtrָʾ��6�ֽڼ��ص��Ĵ��� gdtr��

	; ���ж�
	cli

	; �򿪵�ַ��A20
	in	al, 92h
	or	al, 00000010b
	out	92h, al

	; ׼���л�������ģʽ
	mov	eax, cr0
	or	eax, 1  ; Mine���� cr0 ��PEλ��1���ͱ�ʾʵģʽ�ˡ�
	mov	cr0, eax

	; �������뱣��ģʽ
	jmp	dword SelectorCode32:0	
					; ִ����һ���� SelectorCode32 װ�� cs, 
					; ����ת�� Code32Selector:0  ��
					; Mine��SelectorCode32��¼��LABEL_DESC_CODE32�����ȫ�����������ƫ�Ƶ�ַ,��LABEL_DESC_CODE32��¼��LABEL_SEG_CODE32�Ļ���ַ��
; END of [SECTION .s16]


[SECTION .s32]; 32 λ�����. ��ʵģʽ����. ; Mine���öγ�����ʵģʽ��ִ�У���Ϊ or eax,1 �Ѿ���������ģʽΪʵģʽ�ˡ�
[BITS	32]

LABEL_SEG_CODE32:
	mov	ax, SelectorVideo ; Mine��SelectorVideo��ΪLABEL_DESC_VIDEO�����ȫ����������GDT��ѡ���ӡ�
	mov	gs, ax			; ��Ƶ��ѡ����(Ŀ��)

	mov	edi, (80 * 11 + 79) * 2	; ��Ļ�� 11 ��, �� 79 �С�
	mov	ah, 0Ch			; 0000: �ڵ�    1100: ����
	mov	al, 'P'
	mov	[gs:edi], ax ; Main�� LABEL_DESC_VIDEO ���Դ��׵�ַ���� SelectorVideo ��ΪLABEL_DESC_VIDEO�����ȫ��������GDT��ƫ�Ƶ�ַ��

	; ����ֹͣ
	jmp	$

SegCode32Len	equ	$ - LABEL_SEG_CODE32
; END of [SECTION .s32]

