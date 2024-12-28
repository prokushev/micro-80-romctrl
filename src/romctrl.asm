; ═══════════════════════════════════════════════════════════════════════
; ПРОГРАММА УПРАВЛЕНИЯ ROM-DISK/32K ДЛЯ КОМПЬЮТЕРОВ:
; * "МИКРО-80" С МОНИТОРОМ, СОВМЕСТИМЫМ С "РАДИО-86РК"
; * "РАДИО-86РК" С OБЪEMOM ОЗУ ПОЛЬЗОВАТЕЛЯ 16К/32К
; * ЮТ-88 С МОНИТОРОМ F (ЖУРНАЛЬНЫЙ ВАРИАНТ)
; * ЮТ-88 С МОНИТОРОМ F (ВЕРСИЯ 1.01 С ZX-PK.RU)
; ПРОГРАММА УПРАВЛЕНИЯ ЗАФИКСИРОВАНА В ПЗУ
; ПО АДРЕСАМ 7E00H-7FFFH. УКАЗАННУЮ ОБЛАСТЬ ПЗУ 
; ЗАПРЕЩЕНО ИСПОЛЬЗОВАТЬ ПОД ROM-ДИСК. 
; ПРОГРАММА ИЗ ROM-ДИСК В ОЗУ ПЕРЕНОСИТСЯ ЗАГРУЗЧИКОМ
; (В МОНИТОРЕ) ПО ДИРЕКТИВЕ "U" или "R".
; R7E00,7FFF<ВК>  G<ВК>
; ПРОГРАММА УПРАВЛЕНИЯ ПОЗИЦИОННО-НЕЗАВИСИМАЯ.
; ═══════════════════════════════════════════════════════════════════════

	CPU		8080
	Z80SYNTAX	EXCLUSIVE

; ───────────────────────────────────────────────────────────────────────
; Адреса системных вызовов
; ───────────────────────────────────────────────────────────────────────

	INCLUDE	"syscalls.inc"

; ───────────────────────────────────────────────────────────────────────
; Макросы для относительного перехода относительно текущего адреса.
; Не работает для первого операнда:
; REL LD Label1, HL - не работает
; ───────────────────────────────────────────────────────────────────────

REL	MACRO	CMD, ADDR
	RST	0
	IF	ARGCOUNT==2
	CMD, (ADDR-$) & 0ffffh
	ELSE
	CMD-$
	ENDIF
	ENDM

; ───────────────────────────────────────────────────────────────────────

; ───────────────────────────────────────────────────────────────────────
; Начало.
; ВАЖНО! Из-за бага в ЮТ-88 стандартно загрузится первые 256 байт, а
; дальше опять будут повторяться эти же 256 байт. Поэтому 
; все действия при инициализации (до входа в цикл меню)
; должны умещаться в эти первые 256 байт. После настройки всего,
; чего надо, догружаем остальные 256 байт и работаем дальше. (Не актуально?)
; ───────────────────────────────────────────────────────────────────────

	ORG	7400H		; По факту грузить можем в любые адреса
Start:

; ───────────────────────────────────────────────────────────────────────
; Определяем адрес запуска программы
; выход: DE=BaseAddress
; ───────────────────────────────────────────────────────────────────────
	LD	HL, (0)			; эта область затрется при загрузке с 0..2
MaxItems:				; здесь затрется данными
	EX	DE, HL			; DE=(0)
RST0_0					; DW 0
RST0_2:	EQU	$+2			; DB 0
	LD	HL, 0E9E1H		; POP HL ! JP(HL)
T:	LD	(0), HL			; DB 0FH DUP 0
	RST	0			; HL=BaseAddress
BaseAddress:
; ───────────────────────────────────────────────────────────────────────
; Устанавливаем по адресу RST 0 переход на обработчик относительного
; адреса
; ───────────────────────────────────────────────────────────────────────
	LD	A, 0C3H			; JMP ...
	LD	(0), A
	LD	A, (2)			; Сохраняем данные
	LD	BC, RST0-BaseAddress	; Смещение до обработчика
	ADD	HL, BC			; HL=RST0
	LD	(1), HL			; Адрес обработчика RST 0
	EX	DE, HL			; DE=RST0, HL=(0)
; ───────────────────────────────────────────────────────────────────────
; Сохраняем данные адресов 0-2 для последующего восстановления
; ───────────────────────────────────────────────────────────────────────
	RST	0
	LD	((RST0_0-$) & 0ffffh), HL
	RST	0
	LD	((RST0_2-$) & 0ffffh), A
; ───────────────────────────────────────────────────────────────────────
; Проверяем наличие Микро-80 (Монитор РК)
; ───────────────────────────────────────────────────────────────────────
	LD	A, (0FFD8H)		; Проверяем наличие Микро-80 с М/80К
	CP	038H			; Букава 'm' от приветствия
	LD	DE, 0F9E6H		; Адрес копирования ROM-диска в Микро-80

	REL	JP Z, PatchROM		; Если да, то патчим

; ───────────────────────────────────────────────────────────────────────
; Проверяем наличие ЮТ-88 (Монитор F 1.01)
; ───────────────────────────────────────────────────────────────────────
	CP	023H			; Код 23h
	LD	DE, 0FA62H		; Адрес копирования ROM-диска в ЮТ-88
	REL	JP Z, PatchROM		; Если да, то патчим
; ───────────────────────────────────────────────────────────────────────
; У нас Радио-86РК
; ───────────────────────────────────────────────────────────────────────
	LD	DE, ReadROM		; Адрес копирования ROM-диска в Радио-86РК
; ───────────────────────────────────────────────────────────────────────
; Патчим адрес директивы чтения из ПЗУ
; ───────────────────────────────────────────────────────────────────────
PatchROM:
	REL	LD HL, CallReadROM+1
	LD	(HL), E
	INC	HL
	LD	(HL), D

; ───────────────────────────────────────────────────────────────────────
; Выводим каталог диска
; ───────────────────────────────────────────────────────────────────────
	LD	B, 0			; Первый элемент выбран
InputLoop:
	REL	LD HL, SO1
	PUSH	HL
	CALL	PrintString
	POP	HL
	LD	(HL), 0CH		; Заменяем CrlScr на Home
	REL	CALL SEARCHS
	REL	LD HL, MaxItems
	DEC	C
	LD	(HL), C
	REL	LD HL, SO3		; Печатаем перевод строки
	CALL	PrintString
; ───────────────────────────────────────────────────────────────────────
; Обрабатываем меню
; ───────────────────────────────────────────────────────────────────────
	CALL	InputSymbol
	SUB	0CH
	JP	Z, WarmBoot

	DEC	A			; 0DH
	REL	JP Z, ExitLoop

	SUB	1BH-0DH			; 1BH
	JP	Z, WarmBoot

	INC	A			; 1AH
	REL	JP NZ, Next1

	LD	A, B
	REL	LD HL, MaxItems
	CP	(HL)
	REL	JP Z, Next2
	INC	B
	REL	JP Next2
Next1:
	INC	A			; 19H
	REL	JP NZ, Next2
	LD	A, B
	OR	A
	REL	JP Z, Next2
	DEC	B
Next2:
	REL	JP InputLoop
ExitLoop:
; ───────────────────────────────────────────────────────────────────────
; Изменяем возврат из функции печати на "провал" в функцию запуска программы
; ───────────────────────────────────────────────────────────────────────
	XOR	A
	RST	0
	LD	(Patch5-$), A
; ───────────────────────────────────────────────────────────────────────
; Запускаем выбранную программу
; ───────────────────────────────────────────────────────────────────────
					; Просто проваливаемся дальше
; ───────────────────────────────────────────────────────────────────────
; Подпрограмма перебора каталога диска
; ───────────────────────────────────────────────────────────────────────
;0-7 - ИМЯ ФАЙЛА. МОЖЕТ СОДЕРЖАТЬ НЕ БОЛЕЕ 8 СИМВОЛОВ. ЕСЛИ ИМЯ СОДЕРЖИТ МЕНЬШЕ СИМВОЛОВ, СВОБОДНЫЕ ЯЧЕЙКИ ЗАПОЛНЯЮТСЯ ПРОБЕЛАМИ.
;8-9 - НАЧАЛЬНЫЙ АДРЕС РАЗМЕЩЕНИЯ ПРОГРАММЫ ПРИ СЧИТЫВАНИИ ЕЕ ИЗ ДИСКА В ОЗУ - АДРЕС "ПОСАДКИ".
;А-В - РАЗМЕР ФАЙЛА. В ЭТОТ ПАРАМЕТР ОГЛАВЛЕНИЕ ФАЙЛА(16 БАЙТ) НЕ ВХОДИТ.
;С - БАЙТ ФЛАГОВ. В "ORDOS" V2.X ИСПОЛЬЗУЕТСЯ ТОЛЬКО БИТ D7. СОСТОЯНИЕ "1" УКАЗЫВАЕТ НА ТО, ЧТО ФАЙЛ ЗАЩИЩЕН ОТ УНИЧТОЖЕНИЯ. ОСТАЛЬНЫЕ БИТЫ ЗАРЕЗЕРВИРОВАНЫ ДЛЯ РАСШИРЕНИЯ. ИЗМЕНЕНИЕ СОСТОЯНИЯ БИТА D7 ПРОИЗВОДЯТ ВНЕШНИЕ ЗАГРУЖАЕМЫЕ ДИРЕКТИВЫ ОПЕРАЦИОННОЙ СИСТЕМЫ.
;D-F - СЛУЖЕБНЫЕ ЯЧЕЙКИ СИСТЕМЫ.

SEARCHS:LD	DE, 0800H
	LD	C, E
SEARCH:	PUSH	BC
	REL	LD BC, T
	LD	HL, 0FH
	ADD	HL, DE
	EX	HL, DE
	PUSH	BC
	REL	CALL CallReadROM; HL - начало, DE - конец, BC - посадка
	POP	BC
	INC	DE
	LD	A,(BC)
	INC	A		; Если был 0FFH, то станет 0
	POP	BC
	RET	Z		; Файлы кончились, выходим
	REL	CALL PRINTN
	INC	C
	REL	LD HL, T+8+2
	LD	A, L			; высчитываем начало следующей записи
	AND	0FH
	LD	A, L
	REL	JP Z, SKIP
	OR	0FH
	INC	A
	LD	L, A
	
SKIP:	
	ADD	HL, DE
	EX	DE, HL
	REL	JP SEARCH

; ───────────────────────────────────────────────────────────────────────
; Подпрограмма печати записи каталога
; ───────────────────────────────────────────────────────────────────────
PRINTN:
	PUSH	BC

	LD	A, C

	LD	C, 06H
	CALL	PrintCharFromC

	SUB	B
	LD	C, ' '
	REL	JP NZ, NotActive1
	LD	C, 0EH
NotActive1:
	CALL	PrintCharFromC

	LD	B, 8
	REL	LD	HL, T
PLOOP:	LD	C, (HL)			; Печатаем имя
	CALL	PrintCharFromC
	INC	HL
	DEC	B
	REL	JP NZ, PLOOP

	INC	HL
	
	POP	BC
	PUSH	BC
	
	LD	A, C
	SUB	B
	LD	C, ' '
	REL	JP NZ, NotActive2
	LD	C, 1DH
NotActive2:
	CALL	PrintCharFromC
	REL	CALL PrintHexWord	; Печатаем стартовый адрес

	INC	HL
	INC	HL
	INC	HL
	LD	C, ' '			; Печатаем размер
	CALL	PrintCharFromC
	REL	CALL PrintHexWord

	LD	C, 11h
	CALL	PrintCharFromC
	REL	LD HL, SO2		; Печатаем перевод строки
	CALL	PrintString

	POP	BC
Patch5:	RET				; Заменяется на 0, когда надо запустить

; ───────────────────────────────────────────────────────────────────────
; Подпрограмма запуска программы
; ───────────────────────────────────────────────────────────────────────
EXECN:
	LD	A, C
	SUB	B
	RET	NZ

	LD	C, 1Fh		; Очищаем экран перед запуском
	CALL	PrintCharFromC
	
	REL	LD HL, T+8
	LD	B, H
	LD	C, L
	REL	LD HL, T+8+2

	ADD	HL, DE
	EX	DE, HL

	PUSH	BC		; Адрес запуска
;	REL	JP CallReadROM	; Читаем в ОЗУ и запускаем программу
CallReadROM:
	JP	ReadROM		; Здесь потом адрес пропатчится
	
PrintHexWord:
	LD	A, (HL)
	CALL	PrintHexByte
	DEC	HL
	LD	A, (HL)
	JP	PrintHexByte

; ───────────────────────────────────────────────────────────────────────
; Подпрограмма модификации относительного адреса перехода
; ───────────────────────────────────────────────────────────────────────
RST0:	EX	(SP),HL		; Save H,L and get next PC
	PUSH	DE		; Save D,E.
	PUSH	AF		; Save condition codes.
	DEC	HL		; Change RST 0 to NOP.
	LD	(HL),00H
	INC	HL

	INC	HL
	LD	E,(HL)		; Get relative addr. in D, E.
	INC	HL
	LD	D,(HL)
	EX	DE,HL		; Add offset for abs. addr.
	ADD	HL,DE
	EX	DE,HL
	DEC	DE		; Set to beginning of instr
	DEC	DE
	LD	(HL),D		; Store absolute addr.
	DEC	HL
	LD	(HL),E
	POP	AF		; Restore condition codes.
	POP	DE		; Restore D,E.
	DEC	HL		; Set H,L to start of instr
	EX	(SP),HL		; Restore H,L
	RET

	
SO1:	DB 	1FH, "*ROM-DISK/32K* V3.0-24"
	DB 	0AH,0DH," \x14\x14\x14\x14\x14\x14\x14\x14\x14\x14\x14\x14\x14\x14\x14\x14\x14\x14\x14"
SO2:	DB	0AH,0DH, 0
SO3:	DB 	" \x3\x3\x3\x3\x3\x3\x3\x3\x3\x3\x3\x3\x3\x3\x3\x3\x3\x3\x3",0dh,0ah
	DB	"ar2-wyhod,",0Bh,0Fh,"-wybor,wk-pusk",0

	DB	7600H-$ DUP (0FFH)
