;
;V13
;
; Created: 20/12/2019
; Author : lengel01, pkern01
;


.equ RS = 0 
.equ E = 1
.equ D4 = 4
.equ D5 = 5
.equ D6 = 6
.equ D7 = 7
.equ LCD = PORTA
.equ c1_1=0x80 .equ c1_2=0x81.equ c1_3=0x82.equ c1_4=0x83.equ c1_5=0x84.equ c1_6=0x85.equ c1_7=0x86.equ c1_8=0x87.equ c1_9=0x88.equ c1_10=0x89.equ c1_11=0x8A.equ c1_12=0x8B.equ c1_13=0x8C.equ c1_14=0x8D.equ c1_15=0x8E.equ c1_16=0x8F.equ c1_17=0x90.equ c1_18=0x91.equ c1_19=0x92.equ c1_20=0x93.equ c2_1=0xC0.equ c2_2=0xC1.equ c2_3=0xC2.equ c2_4=0xC3.equ c2_5=0xC4.equ c2_6=0xC5.equ c2_7=0xC6.equ c2_8=0xC7.equ c2_9=0xC8.equ c2_10=0xC9.equ c2_11=0xCA.equ c2_12=0xCB.equ c2_13=0xCC.equ c2_14=0xCD.equ c2_15=0xCE.equ c2_16=0xCF.equ c2_17=0xD0.equ c2_18=0xD1.equ c2_19=0xD2.equ c2_20=0xD3.equ c3_1=0x94.equ c3_2=0x95.equ c3_3=0x96.equ c3_4=0x97.equ c3_5=0x98.equ c3_6=0x99.equ c3_7=0x9A.equ c3_8=0x9B.equ c3_9=0x9C.equ c3_10=0x9D.equ c3_11=0x9E.equ c3_12=0x9F.equ c3_13=0xA0.equ c3_14=0xA1.equ c3_15=0xA2.equ c3_16=0xA3.equ c3_17=0xA4.equ c3_18=0xA5.equ c3_19=0xA6.equ c3_20=0xA7.equ c4_1=0xD4.equ c4_2=0xD5.equ c4_3=0xD6.equ c4_4=0xD7.equ c4_5=0xD8.equ c4_6=0xD9.equ c4_7=0xDA.equ c4_8=0xDB.equ c4_9=0xDC.equ c4_10=0xDD.equ c4_11=0xDE.equ c4_12=0xDF.equ c4_13=0xE0.equ c4_14=0xE1.equ c4_15=0xE2.equ c4_16=0xE3.equ c4_17=0xE4.equ c4_18=0xE5.equ c4_19=0xE6.equ c4_20=0xE7
.equ max_operation = 0x07

.dseg
	index: .BYTE 1				;on reserve un octet de la RAM

.cseg
.org 0							; se placer au début de la mémoire programme
	rjmp reset					; allez à l'adresse du reset

	
;#######################################################################################################################################################################
;INITIALISATION
;#######################################################################################################################################################################

.org 0x10						;se placer à la case mémoire 10 en hexa
;texte à afficher à l'initialisation. La valeur 0x7F indique que la prochaine valeur doit être envoyée comme commande, et la valeur 0x7E indique la fin de la chaîne
;la valeur initiale 0x00 sert à décaler pour que index commence à 1
table:
.db		0x00, 0x7F, c1_1, 0xFF, 'K', 'E', '-', '1', 0xFF, 0x7F, c2_1, 'E', 'N', 'G', 'E', 'L', 0x7F, c3_1, 'K', 'E', 'R', 'N', 0x7f, c4_1, 'G', 'E', '4', 0x7E

reset:							;adresse du vecteur de reset
	ldi		r16, high (RAMEND)	;initialisation de la pile
	out		SPH, r16
	ldi		r16, low (RAMEND)
	out		SPL, r16

	ldi		r16,0xff			;initialise le port de la led en sortie
	out		DDRA,r16

	ldi		r16, 0x03
	out		DDRB,r16

	;Initialisation LCD
	ldi		r18, 0x2C			;indique au LCD qu'on n'utilise que 4 bits
	rcall	envoi_commande

	ldi		r18, 0x0E			;afficher le curseur en clignotant
	rcall	envoi_commande

	ldi		r18, 0x80			
	rcall	envoi_commande

	ldi		r18, 0x01			;clear l'affichage
	rcall	envoi_commande

	clr		r25
	sbr		r19, 1

	clr		r16
	sts		index, r16

	;Initialisation ADC
	ldi		r16,0x00			;OPTIONNEL - configuration de format de sortie (2 bits sur ADCH et 8 bits sur ADCL) et conversion en "Free Running Mode"
	out		ADCSRB,r16

	ldi		r16,0x80
	out		ADCSRA,r16			;démarrage du convertisseur et tout le reste est désactivé (possibilité de ne set que le bit utile)

;#######################################################################################################################################################################
;START
;#######################################################################################################################################################################

start:
	;############################# LECTURE ENTREES
	ldi		r16,0x07			;configuration de l'ADC sur l'entrée ADC7
	out		ADMUX, r16			;on choisit le convertisseur sur le port ADC7
	rcall	conversion			;on lance la conversion et on enregistre le résultat

	ldi		r16,0x06			;configuration de l'ADC sur l'entrée ADC6
	out		ADMUX, r16			;on choisit le convertisseur sur le port ADC6
	rcall	conversion			;on lance la conversion et on enregistre le résultat

	rcall	lecture_boutons
	
	;############################# ANALYSE DES BOUTONS
	rcall	analyse_boutons

	;############################# MODIFICATION OPERANDES
	;Objectif : détecter si on est en train de modifier un des opérandes
	mov		r16, r22			;on copie r22 (registre de contrôle du calcul) pour récupérer l'avancement
	andi	r16, 0x10			;on applique un masque 000x 0000 pour ne garder que le bit de poids fort de l'avancement
	mov		r17, r21			;on copie r21 (registre des entrées) pour récupérer les entrées de l'axe X du Joystick
	andi	r17, 0x06			;on applique un masque 0000 0xx0 pour ne garder que les bits "utilisé" et "zone morte"
	lsl		r17					;on décale r17 deux fois à gauche pour aligne le bit 4 de r16 et le bit 2 de r17
	lsl		r17
	or		r16, r17			;on fait l'addition entre les deux bits
	lsl		r17					;on décale pour aligne le bit 1 de r17
	or		r16, r17			;on fait l'addition entre les bits
	sbrs	r16, 4				;on skip si le résultat n'est pas à 1
	rcall	modif_operande

	;############################# MODIFICATION DE L'OPERATION
	;Objectif : détecter si on est en train de modifier l'opération
	mov		r16, r21
	mov		r17, r21
	lsl		r17
	or		r16, r17
	sbrs	r16, 5
	rcall	modif_operation

	;############################# AFFICHAGE
	rcall	affichage

	rjmp start

	
;#######################################################################################################################################################################
;SOUS PROGRAMMES
;#######################################################################################################################################################################



tempo:
	ldi		r30,0xff			; r30 = 255
boucletempo:
	dec		r30					; r30-1
	nop							; rien pendant un cycle
	brne	boucletempo			; retourne à boucletempo si r30 =! 0
	dec		r31					; r31-1
	brne	tempo				; retourne à tempo
	ret							; retourne  à rcall 

;Sous programme de conversion

conversion:
	sbi		ADCSRA,6			;démarrage de la conversion
	clr		r17					;on force r17 à 0000 0000 (potentiellement supprimable)
attenteconv:
	in		r16,ADCSRA			;on stocke le registre ADCSRA 

	andi	r16,0x40			;on applique le masque pour vérifier l'avancement de la conversion
	cpi		r16,0x40			;on compare à la valeur attendue lorsque la conversion est en cours (simplifiable en une instruction?)

	breq	attenteconv			;on retourne à attenteconv si la conversion n'est pas terminée

	sbis	ADMUX, 0			;selon quel convertisseur a été utilisé, on enregistre en tant que X ou Y
	rcall	save_x
	sbic	ADMUX, 0
	rcall	save_y

	ret

;Sous programme de sauvegarde des donnés de l'axe des chiffres
save_x:
	in		r16, ADCH			;on enregistre le résultat de la conversion dans r16
	mov		r17, r16			;on stocke r16 and r17
	;on set le bit 0 de r21 à la même valeur que le bit 0 de r16 (= la donnée)
	andi	r16, 0x01			;masque 0000 000x
	cbr		r21, 1				;on clear le bit 0 (bit 0 = 0000 0001 = 1) de r21
	or		r21, r16
	;XOR entre le bit 0 et le bit 1 de r16 (= la zone morte)
	lsl		r16					;shift de r16 pour aligne le bit 0 et le bit 1
	eor		r16, r17
	andi	r16, 0x02			;masque 0000 00x0
	cbr		r21, 2				;on clear le bit 1 (bit 1 = 0000 0010 = 2) de r21
	or		r21, r16
	;Bit "Utilisé"
	sbrc	r21, 1				;si on est dans la zone morte, on force le bit Utilisé à 0
	cbr		r21, 4				;bit 2 = 0000 0100 = 4
	ret
	
;Sous programme de sauvegarde des donnés de l'axe des opérations
save_y:
	in		r16, ADCH			;on enregistre le résultat de la conversion dans r16
	lsl		r16
	lsl		r16
	lsl		r16
	mov		r17, r16			;on stocke r16 and r17
	;on set le bit 0 de r21 à la même valeur que le bit 0 de r16 (= la donnée)
	andi	r16, 0x08			;masque 0000 x000
	cbr		r21, 8				;on clear le bit 3 (bit 3 = 0000 1000 = 8) de r21
	or		r21, r16
	;XOR entre le bit 0 et le bit 1 de r16 (= la zone morte)
	lsl		r16					;shift de r16 pour aligne le bit 0 et le bit 1
	eor		r16, r17
	andi	r16, 0x10			;masque 000x 0000
	cbr		r21, 16				;on clear le bit 4 (bit 4 = 0001 0000 = 16) de r21
	or		r21, r16
	;Bit "Utilisé"
	sbrc	r21, 4				;si on est dans la zone morte, on force le bit Utilisé à 0
	cbr		r21, 32				;bit 5 = 0010 0000 = 32
	ret


;Sous programme de sauvegarde de l'état des boutons
lecture_boutons:
	in		r16, PINB			;lecture du PORTB pour récupérer les boutos sur PB0 et PB1 (r16 de la forme : ???? ??xx)
	swap	r16					;inversion des quartets (r16 = ??xx ????)
	lsl		r16					;on décale 2 fois à gauche
	lsl		r16					;pour avoir r16 = xx?? ??00
	andi	r16, 0xC0			;masque r16 pour forcer tout ce qui n'est pas intéressant à 0 (xx00 0000)
	andi	r21, 0x3F			;masque r21 pour reset les 2 bits de poids fort (00xx xxxx)
	or		r21, r16			;on sauvegarde la valeur des boutons dans r21
	sbrs	r21, 6				;si on a relâché le bouton latéral, on clear le bit de skip tempo
	cbr		r20, 4
	ret

;#######################################################################################################################################################################
;Affichage LCD
;#######################################################################################################################################################################


;En fonction du type d'envoi RS est à l'état haut ou à l'état bas
envoi_donnee:
	ldi		r31, 0x02
	rcall	tempo			;tempo
	mov		r16, r18		;sauvegarde de r18 dans r16
	andi	r18, 0xf0		;masque pour garder les bits sur D7, D6, D5, D4
	out		LCD, r18		;écriture du nipple de poids fort sur le LCD
	sbi		LCD, RS			;on set le bit RS pour indiquer que c'est une donnée			
	sbi		LCD, E			;impulsion sur E
	cbi		LCD, E

	mov		r18, r16		;on récupère r18
	swap	r18
	andi	r18, 0xf0		;masque pour garder les bits sur D7, D6, D5, D4
	out		LCD, r18		;écriture du nipple de poids fort sur le LCD
	sbi		LCD, RS			;on set le bit RS pour indiquer que c'est une donnée
	sbi		LCD, E			;impulsion sur E
	cbi		LCD, E 

	ret

envoi_commande:
	ldi		r31, 0x02
	rcall	tempo			;tempo
	mov		r16, r18		;sauvegarde de r18 dans r16
	andi	r18, 0xf0		;masque pour garder les bits sur D7, D6, D5, D4
	out		LCD, r18		;écriture du nipple de poids fort sur le LCD
	cbi		LCD, RS			;on clear le bit RS pour indiquer que c'est une commande
	sbi		LCD, E			;impulsion sur E
	cbi		LCD, E

	mov		r18, r16		;on récupère r18
	swap	r18
	andi	r18, 0xf0		;masque pour garder les bits sur D7, D6, D5, D4
	out		LCD, r18		;écriture du nipple de poids fort sur le LCD
	cbi		LCD, RS			;on clear le bit RS pour indiquer que c'est une commande
	sbi		LCD, E			;impulsion sur E
	cbi		LCD, E 

	ret
	

;Sous programme qui affiche le contenu d'un registre sur le LCD
aff_registre:					;r26 est le registre à afficher, r18 est le curseur (chargée avant le call de aff_registre)
	rcall	envoi_commande		;envoi de la position du curseur
	mov		r17, r26
	ldi		r27, 0x08
aff_bit7:
	sbrs	r17, 7				;si la donnée vaut 0, on envoie "0"
	ldi		r18, '0'
	sbrc	r17, 7				;si la donnée vaut 1, on envoie "1"
	ldi		r18, '1'
	rcall	envoi_donnee
	lsl		r17
	dec		r27
	brne	aff_bit7
	ret

;Selon les bits qui sont set dans r19, on met à jour certaines parties de l'affichage
affichage:
	sbrc	r19, 0				;si le bit 0 de r19 est à 1, on va mettre à jour tout l'affichage
	ser		r19
	
	sbrc	r19, 1
	rcall	aff_operande_1

	sbrc	r19, 2
	rcall	aff_operande_2

	sbrc	r19, 3
	rcall	aff_resultat_carry

	sbrc	r19, 4
	rcall	aff_operation

	sbrc	r19, 5
	rcall	aff_autre

	;On place le curseur au bon endroit en fonction de l'avancement du calcul pour que l'utilisateur sache où il rentre l'opérande
	sbrs	r22, 3				;si on est en train de modifier un opérande, on le place sous le bon
	ldi		r18, c1_20
	sbrc	r22, 3
	ldi		r18, c2_20
	sbrs	r22, 4
	rcall	envoi_commande

	ldi		r18, c4_20			;si on est en train d'afficher le résultat, on le place sous ce dernier
	sbrc	r22, 4
	rcall	envoi_commande

	clr		r19					;on ne doit plus mettre à jour l'affichage
	ret

aff_operande_1:
	ldi		r18, c1_13			;on positionne le curseur au bon endroit		
	mov		r26, r23			;on copie l'opérande 1 dans le registre à afficher bit par bit
	rcall	aff_registre		;on affiche le registre
	ret

aff_operande_2:
	ldi		r18, c2_13			;on positionne le curseur au bon endroit		
	mov		r26, r24			;on copie l'opérande 2 dans le registre à afficher bit par bit
	rcall	aff_registre		;on affiche le registre
	ret

aff_resultat_carry:
	ldi		r18, c4_13			;on positionne le curseur au bon endroit		
	mov		r26, r25			;on copie le résultat dans le registre à afficher bit par bit
	rcall	aff_registre		;on affiche le registre

	ldi		r18, c4_9			;on positionne le curseur sur case de la carry
	rcall	envoi_commande		;on bouge le curseur
	ldi		r18, 'C'			;on affiche un 'C'
	rcall	envoi_donnee
	ldi		r18, ':'			;on affiche un ':'
	rcall	envoi_donnee
	sbrs	r28, 0				;si la retenue vaut 0, on envoie "0"
	ldi		r18, '0'
	sbrc	r28, 0				;si la donnée vaut 1, on envoie "1"
	ldi		r18, '1'
	rcall	envoi_donnee
	ret

aff_operation:
	ldi		r18, c2_11			;on place le curseur à l'endroit où on veut afficher le symbole de l'opération
	rcall	envoi_commande
	rcall	charger_operation	;on charge dans r18 le symbole à envoyer selon l'opération choisie
	rcall	envoi_donnee
	ret

;Affichage de la barre de calcul et des noms
aff_autre:
	;Affichage de la barre de calcul via un "for" qui affiche un tiret 8 fois
	ldi		r18, c3_13
	rcall	envoi_commande
	
	ldi		r17, 0x08
while_barre_calcul:
	ldi		r18, '-'
	rcall	envoi_donnee
	dec		r17
	brne	while_barre_calcul

	;Affichage des noms
boucle_init:
	rcall	inc_index			;on incrémente index
	rcall	lire_memoire		;on cherche la valeur à l'index index
	cpi		r18, 0x7E			;on la compare avec la valeur STOP
	breq	fin_init_aff		;si c'est le cas, on quitte le sous programme
	cpi		r18, 0x7F			;on test si c'est une valeur indiquant une commande
	brne	donnee_init			;si non, on envoie la valeur lue en donnée
	rcall	inc_index			;si oui, on va chercher la valeur suivante
	rcall	lire_memoire
	rcall	envoi_commande		;et on l'envoie en tant que commande
	rjmp	boucle_init			;on recommence jusqu'à arriver à la fin
donnee_init:
	rcall	envoi_donnee
	rjmp	boucle_init
fin_init_aff:
	ret
	

;sous programme pour incrémenter la valeur de index
inc_index:
	lds		r16,index			;on charge index dans r16
	inc		r16					;on incrémente r16
	andi	r16,0x1F			;on masque de type 000x xxxx
	sts		index,r16			;on stock la valeur dans index
	ret

;sous programme pour lire la valeur dans la mémoire à l'adresse index
lire_memoire:
	ldi		zl, LOW(table)		;on met l'octet de poids faible de l'adresse de la table dans ZL
	ldi		zh, HIGH(table)		;on met l'octet de poids fort de l'adresse de la table dans ZH
	lsl		zl					;décalage gauche de ZL
	lds		r16, index			;on met index dans r16
	add		zl, r16				;on ajoute r16 à ZL
	ldi		r16, 0x40			;on enregistre la constante 0x40 pour se placer dans la mémoire programme
	add		zh, r16				;on ajoute r16 à ZH
	ld		r18, z				;on met la valeur à l'adresse z dans r18				
	ret

;sous programme permettant de choisir quelle opération à afficher à l'écran
charger_operation:				
	mov		r16, r22			;on copie r22 dans r16 pour récupérer seulement les bits de l'opération
	andi	r16, 0x07			;on applique un masque de type 0000 0xxx
	;Pour chaque opération, on compare r16 avec son code et on branche si c'est le bon
	cpi		r16, 0x00
	breq	symb_addition
	cpi		r16, 0x01
	breq	symb_soustraction
	cpi		r16, 0x02
	breq	symb_et_logique
	cpi		r16, 0x03
	breq	symb_ou_logique
	cpi		r16, 0x04
	breq	symb_ouex_logique
	cpi		r16, 0x05
	breq	symb_non_logique
	cpi		r16, 0x06
	breq	symb_comp_a_2
	cpi		r16, 0x07
	breq	symb_decal_droite
	ret

;Pour chaque opération, on sauvegarde dans r18 le code ASCII du symbole de l'opération
;et on vérifie si l'opérateur est unaire ou binaire
symb_addition:
	ldi		r18, '+'
	cbr		r20, 1
	ret
symb_soustraction:
	ldi		r18, '-'
	cbr		r20, 1
	ret
symb_et_logique:
	ldi		r18, '&'
	cbr		r20, 1
	ret
symb_ou_logique:
	ldi		r18, '|'
	cbr		r20, 1
	ret
symb_ouex_logique:
	ldi		r18, '^'
	cbr		r20, 1
	ret
symb_non_logique:
	ldi		r18, '!'
	sbr		r20, 1
	ret
symb_comp_a_2:
	ldi		r18, 0xF8
	sbr		r20, 1
	ret
symb_decal_droite:
	ldi		r18, '>'
	sbr		r20, 1
	ret
	
;#######################################################################################################################################################################
;CALCULS
;#######################################################################################################################################################################

;sélectionne l'opérande à modifier en focntion de l'avancement du calcul
modif_operande:
	sbrs	r22, 3				;si le bit de poids faible de l'avancement est à 0, on modifie le premier opérande
	rcall	modif_operande_1
	sbrc	r22, 3				;si le bit de poids faible de l'avancement est à 1, on modifie le second opérande
	rcall	modif_operande_2
	ret

;on modifie le premier opérande en le décalant et en ajoutant la donné à la fin
modif_operande_1:
	lsl		r23					;on décale l'opérande à gauche
	sbrc	r21, 0				;si le donnée est à 1 alors on met un 1 en poids faible de l'opérande (pas besoin de traiter le cas donnée = 0 car par défaut ça met un 0)
	sbr		r23, 1
	sbr		r21, 4				;on met le bit "utilisé" du joystick à 1
	sbr		r19, 2				;on doit mettre à jour l'affichage de l'opérande 1
	ret
	
;on modifie le second opérande en le décalant et en ajoutant la donné à la fin
modif_operande_2:
	lsl		r24					;on décale l'opérande à gauche
	sbrc	r21, 0				;si le donnée est à 1 alors on met un 1 en poids faible de l'opérande (pas besoin de traiter le cas donnée = 0 car par défaut ça met un 0)
	sbr		r24, 1
	sbr		r21, 4				;on met le bit "utilisé" du joystick à 1
	sbr		r19, 4				;on doit mettre à jour l'affichage de l'opérande 2
	ret

;sous programme d'analyse de l'état enregistré boutons
analyse_boutons:				;analyse de l'état des boutons
	sbrc	r21, 7				;si le bouton clear est enfoncé, on va au sous programme clear
	rcall	clear
	sbrs	r21, 7				;sinon on regarde de bouton latéral, si le bouton clear est enfoncé, il a la priorité sur le bouton de validation
	rcall	test_lateral
	ret

clear:							;nous avons choisi de ne pas clear le résultat
	clr		r23					;on clear l'opérande 1
	clr		r24					;on clear l'opérande 2
	cbr		r22, 24				;on reset l'avancement : on remet les bits 3 et 4 (3&4 = 0001 1000 = 24) à 0
	sbr		r19, 6				;on doit mettre à jour l'affichage des 2 opérandes
	ret

test_lateral:
	sbrc	r21, 6				;si le bouton validé est enfoncé, on change l'avancement du calcul
	rcall	chg_avancement		
	ret

;permet de changer les 2 bits d'avancement selon l'ordre suivant : 00 -> 01 -> 10 -> 00 (ou 00 -> 10 -> 00 pour les opérations unaires)
chg_avancement:					;contrôle de l'avancement du calcul sur les bits 3 et 4 de r22. On doit les incrémenter mais l'état 11 est interdit, d'où le test suivant
	mov		r16, r22			;on copie r22 dans r16 pour ne pas modifier le vrai r22
	andi	r16, 0x18			;on applique un masque de type 000x x000
	ldi		r17, 0x08			;on charge r17 avec 0000 1000 pour incrémenter les bits 3 et 4 de r16
	add		r16, r17			;on fait la somme r16+r17
	cpi		r16, 0x18			;on compare r16 avec 0001 1000
	brne	pas_fini			;si ce n'est pas égal, on ne fait rien de plus
	clr		r16
	mov		r23, r25			;on remet le résultat dans le premier opérande
pas_fini:
	sbrc	r20, 0				;si l'opération est unaire, on incrémente une nouvelle foi
	rcall	operation_unaire
	andi	r22, 0xE7			;on applique un masque de type xxx0 0xxx à r22
	or		r22, r16			;on remet les bons bits dans r22
	sbrc	r22, 4				;on effectue le calcul si le bit de poids fort de l'avancement est à 1
	rcall	calcul
	sbr		r19, 10				;on doit mettre à jour l'affichage du résultat et de la carry

	;on met une tempo pour laisser le temps à l'utilisateur de relâcher le bouton s'il veut ne faire que changer une fois d'avancement
	ldi		r31, 150
	sbrs	r20, 2				;si le bit de skip tempo est actif, on skip la tempo
	rcall	tempo
	sbr		r20, 4				;on met le bit de skip tempo à 1 pour ne faire la tempo qu'une seule fois
	ret

operation_unaire:
	andi	r16, 0x18			;on masque r16 avec 000x x000
	cpi		r16, 0x08			;on le compare avec 0000 1000
	brne	pas_besoin			;si il est différent, on ne fait rien, sinon on lui donne la valeur 0001 0000
	ldi		r16, 0x10
pas_besoin:
	ret

;sous programme qui permet de tourner entre les différentes opérations
modif_operation:
	sbrs	r21, 3				;selon la direction du joystick, on fait défiler les opérations dans un sens ou dans l'autre
	rcall	dec_operation
	sbrc	r21, 3
	rcall	inc_operation
	sbr		r19, 16				;on doit mettre à jour l'affichage de l'opération
	
	ldi		r31, 255			;on met une tempo pour que les opérations ne défilent trop vite si on laisse le joystick dans une même direction
	rcall	tempo
	ret

;on incrémente le code de l'opération jusqu'au max (enregistré dans max_operation) puis on revient à 0
inc_operation:
	mov		r16, r22			;on copie r22 dans r16
	andi	r16, 0x07			;on applique un masque de type 0000 0xxx
	cpi		r16, max_operation	;on compare avec le code max des opérations
	brne	pas_maximum			;si on est pas au maximum, on incrémente directement le code
	ldi		r16, 0xFF			;sinon, on met r16 à -1 (pour que ça revienne à 0 après l'incrémentation)
pas_maximum:
	inc		r16
	andi	r22, 0xF8			;on applique un masque de type xxxx x000
	or		r22, r16			;on place les 3 bits de poids faible de r16 dans r22
	ret

;on décrémente jusqu'à 0, puis on revient à max_operation
dec_operation:
	mov		r16, r22			;on copie r22 dans r16
	andi	r16, 0x07			;on applique un masque de type 0000 0xxx
	cpi		r16, 0x00			;on compare avec 0
	brne	pas_zero			;si on est pas à zéro, on decrémente directement le code
	ldi		r16, max_operation	;sinon, on met r16 à l'opération max + 1 (pour que ça revienne à l'opération max après la décrementation)
	inc		r16
pas_zero:
	dec		r16
	andi	r22, 0xF8			;on applique un masque de type xxxx x000
	or		r22, r16			;on place les 3 bits de poids faible de r16 dans r22
	ret

;sous programme de calcul (choisit dans quel programme on doit aller selon l'opération)
calcul:							
	mov		r25, r23			;on copie l'opérande 1 dans le résultat en vue du calcul (économise des instructions)
	mov		r16, r22			;on copie r22 dans r16 pour récupérer seulement les bits de l'opération
	andi	r16, 0x07			;on applique un masque de type 0000 0xxx
	;Pour chaque opération, on compare r16 avec son code et on branche si c'est le bon
	cpi		r16, 0x00
	breq	addition
	cpi		r16, 0x01
	breq	soustraction
	cpi		r16, 0x02
	breq	et_logique
	cpi		r16, 0x03
	breq	ou_logique
	cpi		r16, 0x04
	breq	ouex_logique
	cpi		r16, 0x05
	breq	non_logique
	cpi		r16, 0x06
	breq	comp_a_2
	cpi		r16, 0x07
	breq	decal_droite
sortie:
	ret

;Différents calculs possibles
addition:
	add		r25, r24
	in		r28, SREG
	rjmp	sortie
soustraction:
	sub		r25, r24
	in		r28, SREG
	rjmp	sortie
et_logique:
	and		r25, r24
	in		r28, SREG
	rjmp	sortie
ou_logique:
	or		r25, r24
	in		r28, SREG
	rjmp	sortie
ouex_logique:
	eor		r25, r24
	in		r28, SREG
	rjmp	sortie
non_logique:
	com		r25
	in		r28, SREG
	rjmp	sortie
comp_a_2:
	neg		r25
	in		r28, SREG
	rjmp	sortie
decal_droite:
	lsr		r25
	in		r28, SREG
	rjmp	sortie