;@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
;@                                                                            @
;@                            D i s k D u m p e r                             @
;@                                                                            @
;@               (c) 2021 by Prodatron / SymbiosiS (Jörn Mika)                @
;@                                                                            @
;@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@



;==============================================================================
;### CODE AREA ################################################################
;==============================================================================


;### PRGPRZ -> Programm-Prozess
dskprzn     db 2
sysprzn     db 3
windatprz   equ 3   ;Prozeßnummer
windatsup   equ 51  ;Nummer des Superfensters+1 oder 0
prgwin      db 0    ;Nummer des Haupt-Fensters

prgprz  ld a,(App_PrcID)
        ld (prgwindat+windatprz),a

        call prgpar

        ld c,MSC_DSK_WINOPN
        ld a,(App_BnkNum)
        ld b,a
        ld de,prgwindat
        call msgsnd             ;Fenster aufbauen
prgprz1 call msgdsk             ;Message holen -> IXL=Status, IXH=Absender-Prozeß
        cp MSR_DSK_WOPNER
        jp z,prgend             ;kein Speicher für Fenster -> Prozeß beenden
        cp MSR_DSK_WOPNOK
        jr nz,prgprz1           ;andere Message als "Fenster geöffnet" -> ignorieren
        ld a,(prgmsgb+4)
        ld (prgwin),a           ;Fenster wurde geöffnet -> Nummer merken

prgprz0 call msgget
        jr nc,prgprz0
        cp MSR_DSK_WCLICK       ;*** Fenster-Aktion wurde geklickt
        jr nz,prgprz0
        ld a,(iy+2)             ;*** HAUPT-FENSTER
        cp DSK_ACT_CLOSE        ;*** Close wurde geklickt
        jp z,prgend
        cp DSK_ACT_CONTENT      ;*** Inhalt wurde geklickt
        jr nz,prgprz0
prgprz2 ld l,(iy+8)
        ld h,(iy+9)
        ld a,l
        or h
        jr z,prgprz0
        ld a,(iy+3)             ;A=Klick-Typ (0/1/2=Maus links/rechts/doppelt, 7=Tastatur)
        jp (hl)

;### PRGEND -> Programm beenden
prgend  ld a,(App_PrcID)
        db #dd:ld l,a
        ld a,(sysprzn)
        db #dd:ld h,a
        ld iy,prgmsgb
        ld (iy+0),MSC_SYS_PRGEND
        ld a,(App_BegCode+prgpstnum)
        ld (iy+1),a
        rst #10
prgend0 rst #30
        jr prgend0

;### PRGINF -> Info-Fenster anzeigen
prginf  ld hl,prgmsginf         ;*** Info-Fenster
        ld b,1+128
prginf0 ld (prgmsgb+1),hl
        ld a,(App_BnkNum)
        ld c,a
        ld (prgmsgb+3),bc
        ld a,MSC_SYS_SYSWRN
prginf1 ld (prgmsgb),a
        call prginf2
        jp prgprz0
prginf2 ld a,(App_PrcID)
        db #dd:ld l,a
        ld a,(sysprzn)
        db #dd:ld h,a
        ld iy,prgmsgb
        rst #10
        ret


;==============================================================================
;### SUB-ROUTINEN #############################################################
;==============================================================================

;### PRGPAR -> Angehängtes DSK suchen
prgpar  ld hl,(App_BegCode)     ;nach angehängtem DSK suchen
        ld de,App_BegCode
        dec h
        add hl,de               ;HL=CodeEnde=Pfad
        ld b,255
prgpar1 ld a,(hl)
        or a
        ret z
        cp 32
        jr z,prgpar2
        inc hl
        djnz prgpar1
        ret
prgpar2 inc hl
        ld de,prginpsrcb
        ld bc,255
        ldir
        ld ix,prginpsrc
        jp strinp

;### STRINP -> Initialisiert Textinput (abhängig vom String, den es bearbeitet)
;### Eingabe    IX=Control
;### Ausgabe    HL=Stringende (0), BC=Länge (maximal 255)
;### Verändert  AF
strinp  ld l,(ix+0)
        ld h,(ix+1)
        call strlen
        ld (ix+8),c
        ld (ix+4),c
        xor a
        ld (ix+2),a
        ld (ix+6),a
        ret

;### STRLEN -> Ermittelt Länge eines Strings
;### Eingabe    HL=String
;### Ausgabe    HL=Stringende (0), BC=Länge (maximal 255)
;### Verändert  -
strlen  push af
        xor a
        ld bc,255
        cpir
        ld a,254
        sub c
        ld c,a
        dec hl
        pop af
        ret

;### PRGERR -> Disc-Error-Fenster anzeigen
;### Eingabe    E=error code (0=error while accessing disk, 1=unsupported disc type, 2=unsupported disc format, 3=error while writing file)
prgerr0 push de
        ld a,(dsksavhnd)
        call SyFile_FILCLO
        pop de
prgerr  sla e
        ld d,0
        ld hl,prgmsgerrtb
        add hl,de
        ld a,(hl)
        inc hl
        ld h,(hl)
        ld l,a
        ld (prgmsgerra),hl
        ld hl,prgmsgerr
        ld b,1
prgerr2 ld a,(App_BnkNum)
        ld de,prgwindat
        call SySystem_SYSWRN
prgerr1 ld hl,prgtxtsta1
        ld (prgobjsta1),hl
        ld (prgobjsta2),hl
        call prgsta
        jp prgprz0

;### DSKSAV -> Dumps a real disc to a DSK file
dsksav  ld a,(dskdrv)
        add "A"
        ld c,0
        call SyFile_DIRINF
        ld e,0                  ;0 -> error while accessing disk
        jr c,prgerr
        cp 1
        jr nz,prgerr
        inc e                   ;1 -> unsupported disc type
        res 7,b
        dec b
        jr nz,prgerr
        inc e                   ;2 -> unsupported disc format
        ld a,c                      ;1=data (#c0), 2=system (#40), 3=pcw (#00)
        cp 4
        jr nc,prgerr
        cp 2
        ld a,#c0
        ld hl,prgtxtsta10
        jr c,dsksav1
        ld a,#40
        ld hl,prgtxtsta11
        jr z,dsksav1
        ld a,#00
        ld hl,prgtxtsta12
dsksav1 ld (dsksavfrm),a
        ld (prgobjsta1),hl
        call prgsta                 ;show format
        ld ix,(App_BnkNum-1)
        ld hl,prginpsrcb
        xor a
        call SyFile_FILNEW
        ld e,3
        jr c,prgerr
        ld (dsksavhnd),a
        ld a,(trktyp)               ;** disk information block
        add 40
        ld (dsksavhed1),a
        ld hl,dsksavhed2
        ld de,dsksavhed2+1
        ld bc,41
        push hl
        push de
        ld (hl),0
        ldir
        pop de
        pop hl
        ld c,a
        dec c
        ld (hl),#13
        ldir
        ld hl,dsksavhed
        ld bc,256
        call prgsav
        jp c,prgerr0
        ld hl,prgtxtsta21
        ld (prgobjsta2),hl
        xor a
        ld l,a
        ld h,a
        ld (dsksavtrk1),a
dsksav2 ld (dsksavsec),hl           ;** track loop
        ld a,(dsksavtrk1)
        push af
        call clcdez
        ld (prgtxtsta2n),hl
        call prgsta                 ;show current track
        pop af
        ld ix,dsksavtrk2
        ld hl,dsksavilv
        ld de,(dsksavfrm)
        ld d,a
        ld bc,8
        ld iyl,9
dsksav3 ld (ix+0),d                 ;generate sector information
        ld a,(hl)
        add e
        ld (ix+2),a
        inc hl
        add ix,bc
        dec iyl
        jr nz,dsksav3
        ld hl,dsksavtrk
        ld bc,256
        call prgsav
        jp c,prgerr0
        ld a,(dskdrv)               ;A=device (0=a, 1=b)
        ld iy,0
        ld ix,(dsksavsec)
        ld bc,9*256+0
        ld hl,dskbuffer
        ld de,(App_BnkNum)
        call SyFile_STOTRN          ;read all 9 sectors from current track
        ld e,0
        jp c,prgerr0
        ld hl,dsksavilv             ;write sectors interleaved to DSK
        ld b,9
dsksav4 push bc
        push hl
        ld a,(hl)
        dec a
        add a
        ld h,a
        ld l,0
        ld de,dskbuffer
        add hl,de
        ld bc,512
        call prgsav
        pop hl
        pop bc
        jp c,prgerr0
        inc hl
        djnz dsksav4
        ld hl,dsksavhed1            ;next track
        dec (hl)
        jr z,dsksav5
        ld hl,dsksavtrk1
        inc (hl)
        ld hl,(dsksavsec)
        ld c,9
        add hl,bc
        jp dsksav2
dsksav5 ld a,(dsksavhnd)            ;close DSK file
        call SyFile_FILCLO
        ld e,3
        jp c,prgerr
        ld hl,prgmsgsuc
        ld b,1+128
        jp prgerr2

dsksavsec   dw 0                    ;current logical sector
dsksavilv   db 1,6,2,7,3,8,4,9,5    ;interleave sector offset
dsksavhnd   db 0                    ;dsk file handler
dsksavfrm   db 0                    ;format offset (#c0, #40, #00)

dsksavhed
        db "EXTENDED CPC DSK File",13,10,"Disk-Info",13,10
        db "SymbOSDiskDump"         ;identifier
dsksavhed1
        db 40,1,0,0                 ;number of tracks, number of sides, unused, unused
dsksavhed2
        ds 42                       ;track sizes/256 (usually (512*9+256)/256 = #13)
dsksavhed3
        ds 256-dsksavhed3+dsksavhed

dsksavtrk
        db "Track-Info",13,10       ;identifier
        db 0,0,0,0                  ;unused
dsksavtrk1
        db 0,0                      ;track, side
        db 0,0                      ;unused
        db 2,9,#4E,#e5              ;sector size, number of sectors, GAP#3 length, filler byte
dsksavtrk2
        db 0,0,#c1,2,0,0,0,2        ;track, side, sector ID, sector size, fdc status reg1, fdc status reg2, actual data length in bytes
        db 0,0,#c6,2,0,0,0,2
        db 0,0,#c2,2,0,0,0,2
        db 0,0,#c7,2,0,0,0,2
        db 0,0,#c3,2,0,0,0,2
        db 0,0,#c8,2,0,0,0,2
        db 0,0,#c4,2,0,0,0,2
        db 0,0,#c9,2,0,0,0,2
        db 0,0,#c5,2,0,0,0,2
dsksavtrk0
        ds 256-dsksavtrk0+dsksavtrk

;### PRGSAV -> saves data to file
prgsav  ld a,(App_BnkNum)
        ld e,a
        ld a,(dsksavhnd)
        call SyFile_FILOUT
        ld e,3
        ret

;### PRGSTA -> updates status texts
prgsta  ld a,(prgwin)
        ld de,256*15+256-2
        jp SyDesktop_WINDIN

;### PRGSRC -> Source/Destination-file auswählen
prgsrc  ld hl,prginpsrca
        ld a,(App_BnkNum)
        add 64              ;save flag
        ld ix,100
        ld iy,5000
        ld c,8
        ld de,prgwindat
        call SySystem_SELOPN        ;a=0 ok
        or a
        jp nz,prgprz0
        ld a,l
        ld hl,0
        ld (prginpsrc+2),hl
        ld (prginpsrc+4),hl
        ld (prginpsrc+6),hl
        ld (prginpsrc+8),a
        ld a,(prgwin)
        ld e,12
        call SyDesktop_WINDIN
        jp prgprz0

;### MSGGET -> Message für Programm abholen
;### Ausgabe    CF=0 -> keine Message vorhanden, CF=1 -> IXH=Absender, (recmsgb)=Message, A=(recmsgb+0), IY=recmsgb
;### Veraendert 
msgget  ld a,(App_PrcID)
        db #dd:ld l,a           ;IXL=Rechner-Prozeß-Nummer
        db #dd:ld h,-1
        ld iy,prgmsgb           ;IY=Messagebuffer
        rst #08                 ;Message holen -> IXL=Status, IXH=Absender-Prozeß
        or a
        db #dd:dec l
        ret nz
        ld iy,prgmsgb
        ld a,(iy+0)
        or a
        jp z,prgend
        scf
        ret

;### MSGDSK -> Message für Programm von Desktop-Prozess abholen
;### Ausgabe    CF=0 -> keine Message vorhanden, CF=1 -> IXH=Absender, (recmsgb)=Message, A=(recmsgb+0), IY=recmsgb
;### Veraendert 
msgdsk  call msgget
        jr nc,msgdsk            ;keine Message
        ld a,(dskprzn)
        db #dd:cp h
        jr nz,msgdsk            ;Message von anderem als Desktop-Prozeß -> ignorieren
        ld a,(prgmsgb)
        ret

;### MSGSND -> Message an Desktop-Prozess senden
;### Eingabe    C=Kommando, B/E/D/L/H=Parameter1/2/3/4/5
msgsnd0 ld a,(prgwin)
        ld b,a
msgsnd2 ld c,MSC_DSK_WININH
msgsnd  ld a,(dskprzn)
msgsnd1 db #dd:ld h,a
        ld a,(App_PrcID)
        db #dd:ld l,a
        ld iy,prgmsgb
        ld (iy+0),c
        ld (iy+1),b
        ld (iy+2),e
        ld (iy+3),d
        ld (iy+4),l
        ld (iy+5),h
        rst #10
        ret

;### CLCDEZ -> Rechnet Byte in zwei Dezimalziffern um
;### Eingabe    A=Wert
;### Ausgabe    L=10er-Ascii-Ziffer, H=1er-Ascii-Ziffer
;### Veraendert AF
clcdez  ld l,0
clcdez1 sub 10
        jr c,clcdez2
        inc l
        jr clcdez1
clcdez2 add "0"+10
        ld h,a
        ld a,"0"
        add l
        ld l,a
        ret

;### DSK-BUFFER ###############################################################

dskbuffer   db 0        ;9*512 bytes (4096 byte sector/1 track of 9*512 bytes)


;==============================================================================
;### DATEN-TEIL ###############################################################
;==============================================================================

App_BegData

;### Verschiedenes
prgmsginf1  db "DiskDumper",0
prgmsginf2  db " Version 1.0 (Build 211118pdt)",0
prgmsginf3  db " Copyright <c> 2021 SymbiosiS",0

prgwintit   db "DiskDumper 1.0",0

prgtxtint1  db "Please select the source drive",0
prgtxtint2  db "and the destination DSK-file.",0

prgtxtsrc   db "Source",0
prgtxtdrva  db "Drive A",0
prgtxtdrvb  db "Drive B",0

prgtxtdst   db "Destination",0

prgtxttrk   db "Tracks",0
prgtxttrka  db "40",0
prgtxttrkb  db "41",0
prgtxttrkc  db "42",0


prgtxtsta1  db "-",0
prgtxtsta10 db "Data",0
prgtxtsta11 db "System",0
prgtxtsta12 db "PCW",0
prgtxtsta21 db "Dumping track "
prgtxtsta2n db "##",0
prgtxtsta3  db "Format",0
prgtxtsta4  db "Status",0

prgbuttxt1  db "Copy",0
prgbuttxt2  db "Cancel",0
prgbuttxt3  db "Info",0
prgbuttxt4  db "Search",0

prgmsgerrtb dw prgmsgerr00,prgmsgerr01,prgmsgerr02,prgmsgerr03

prgmsgerr00 db "Disc access error",0
prgmsgerr01 db "Unsupported disc type",0
prgmsgerr02 db "Unsupported disc format",0
prgmsgerr03 db "File writing error",0

prgmsgerr1  db "Disc error",0
prgmsgerr0  db "",0 ;"

prgmsgsuc1  db "Congratulation, the DSK file",0
prgmsgsuc2  db "has been created successfully",0
prgmsgsuc3  db "from your original disc!",0

;==============================================================================
;### TRANSFER-TEIL ############################################################
;==============================================================================

App_BegTrns

;### PRGPRZS -> Stack für Programm-Prozess
        ds 128
prgstk  ds 6*2
        dw prgprz
App_PrcID db 0

App_MsgBuf
prgmsgb ds 14

;### INFO-FENSTER #############################################################

prgmsginf  dw prgmsginf1,4*1+2,prgmsginf2,4*1+2,prgmsginf3,4*1+2,prgicnbig

;### ERROR-FENSTER ############################################################

prgmsgerr  dw prgmsgerr1,4*1+2
prgmsgerra dw prgmsgerr0,4*1+2,prgmsgerr0,4*1+2

prgmsgsuc  dw prgmsgsuc1,4*1+2,prgmsgsuc2,4*1+2,prgmsgsuc3,4*1+2,prgicnbig

;### HAUPT-FENSTER ############################################################

prgwindat dw #1501,0,64,44,192,111,0,0,192,111,192,111,192,111,prgicnsml,prgwintit,0,0,prgwingrp,0,0:ds 136+14

prgwingrp db 23,0:dw prgwinobj,0,0,256*00+00,0,0,07
prgwinobj
dw 00    ,255*256+0,2, 0,0,1000,1000,0                  ;00 Hintergrund
dw 00    ,255*256+1 ,prgobjint1,  3,03,186, 8,0         ;01 Einleitung 1
dw 00    ,255*256+1 ,prgobjint2,  3,11,186, 8,0         ;02 Einleitung 2
dw 00    ,255*256+0, 1,           3,22,186, 1,0         ;03 Linie

dw 00    ,255*256+1 ,prgobjsrc ,  3,27, 47, 8,0         ;04 Beschreibung 1
dw 00    ,255*256+18,prgraddsta, 51,27, 45, 8,0         ;05 Radio Drive A
dw 00    ,255*256+18,prgraddstb,100,27, 45, 8,0         ;06 Radio Drive B

dw 00    ,255*256+1 ,prgobjtrk ,  3,41, 47, 8,0         ;07 Beschreibung 3
dw 00    ,255*256+18,prgradtrka, 51,41, 55, 8,0         ;08 Radio Track 40
dw 00    ,255*256+18,prgradtrkb, 77,41, 55, 8,0         ;09 Radio Track 41
dw 00    ,255*256+18,prgradtrkc,102,41, 55, 8,0         ;10 Radio Track 42

dw 00    ,255*256+1 ,prgobjdst ,  3,55, 47, 8,0         ;11 Beschreibung 2
dw 00    ,255*256+32,prginpsrc , 51,53, 88,12,0         ;12 Textinput
dw prgsrc,255*256+16,prgbuttxt4,141,53, 48,12,0         ;13 "Search"-Button

dw 00    ,255*256+0, 1,           3,67,186, 1,0         ;14 Linie
dw 00    ,255*256+1, prgobjsta1, 51,72,138, 8,0         ;15 Typ    Anzeige
dw 00    ,255*256+1, prgobjsta2, 51,82,138, 8,0         ;16 Status Anzeige
dw 00    ,255*256+1, prgobjsta3,  3,72, 47, 8,0         ;17 Typ    Beschreibung
dw 00    ,255*256+1, prgobjsta4,  3,82, 47, 8,0         ;18 Status Beschreibung
dw 00    ,255*256+0, 1,           3,93,186, 1,0         ;19 Linie
dw dsksav,255*256+16,prgbuttxt1, 41,96, 48,12,0         ;20="Copy"-Button
dw prgend,255*256+16,prgbuttxt2, 91,96, 48,12,0         ;21="Cancel"-Button
dw prginf,255*256+16,prgbuttxt3,141,96, 48,12,0         ;22="Info"-Button

prgobjint1 dw prgtxtint1,4+2
prgobjint2 dw prgtxtint2,4+2

prgobjsta1 dw prgtxtsta1,4+2+128
prgobjsta2 dw prgtxtsta1,4+2+128
prgobjsta3 dw prgtxtsta3,4+2
prgobjsta4 dw prgtxtsta4,4+2

prgobjsrc  dw prgtxtsrc,4+2
prginpsrc  dw prginpsrcb,0,0,0,0,255,0
prginpsrca db "dsk",0
prginpsrcb ds 256

prgobjdst  dw prgtxtdst,4+2
prgobjtrk  dw prgtxttrk,4+2

prgradkoo   ds 4
dskdrv      db 0
prgraddsta  dw dskdrv,prgtxtdrva,0*256+2+4,prgradkoo
prgraddstb  dw dskdrv,prgtxtdrvb,1*256+2+4,prgradkoo

prgradkoo2  ds 4
trktyp      db 0
prgradtrka  dw trktyp,prgtxttrka,0*256+2+4,prgradkoo2
prgradtrkb  dw trktyp,prgtxttrkb,1*256+2+4,prgradkoo2
prgradtrkc  dw trktyp,prgtxttrkc,2*256+2+4,prgradkoo2
