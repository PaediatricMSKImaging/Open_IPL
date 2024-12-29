$! IPL_VOIDSPACE.COM  
$! Created to extract major bone void spaces in distal tibia and radius scans
$!
$! Creates files for bone void space analysis and a mask that can allow for 
$! the standard analysis to be re-run on only "functional bone".
$! A visualization of the cavity in the bone region is also created,
$! where the cavity is labelled 57, trabecular region is labelled 126
$! and cortex is labelled 127. 
$!
$! REQUIRED INPUTS: _SEG.AIM, .GOBJ, _TRAB_MASK.GOBJ and _CORT_MASK.GOBJ 
$! Script is currently structured assuming all models are in a .MODELS] 
$! directory and a .MODELS.VOIDSPACE] sub directory exists
$! the sub-directory will be used to store all the generated files
$!
$! Last modified Jun 12, 2020
$! by Danielle Whittier 
$!
$! -----------------------------
$! Get and Define the Arguments
$! -----------------------------
$
$  FILENAME = F$PARSE("''P1'",,,"NAME")
$  DEV      = F$PARSE("''P1'",,,"DEVICE")
$  DIR      = F$PARSE("''P1'",,,"DIRECTORY")
$
$  VOIDDIR  = "''DIR'" - "]" + ".VOIDSPACE]"
$
$
$! input files
$  SEG_FILENAME           	:=  'DEV''DIR''FILENAME'_SEG.AIM 
$  MASK_FILENAME          	:=  'DEV''DIR''FILENAME'.GOBJ
$  TRAB_MASK_FILENAME      	:=  'DEV''DIR''FILENAME'_TRAB_MASK.GOBJ
$  CORT_MASK_FILENAME      	:=  'DEV''DIR''FILENAME'_CORT_MASK.GOBJ
$!
$! temporary files
$!  TBSP_MASK_FILENAME	:=  'DEV''VOIDDIR''FILENAME'_TBSP_MASK.AIM
$!
$! output files
$  VOID_FILENAME          	:=  'DEV''VOIDDIR''FILENAME'_VOID.AIM
$  COMBI_VOID_FILENAME   	:=  'DEV''VOIDDIR''FILENAME'_VOID_COMBI.AIM
$!
$! ---------------
$! Define Logicals
$! ---------------
$  def seg_filename         	'SEG_FILENAME'
$  def mask_filename        	'MASK_FILENAME'
$  def trab_mask_filename   	'TRAB_MASK_FILENAME'
$  def cort_mask_filename   	'CORT_MASK_FILENAME'
$!
$  def void_filename        	'VOID_FILENAME'                 
$  def combi_void_filename  	'COMBI_VOID_FILENAME'
$!
$! -----------------
$! Define variables
$! -----------------
$!
$   tbsp_fill = 12     		!TbSp fill radius for erosion-dilation sequence
$   min_void_vol = 72560	!minimum void space volume
$   misc_param = 6			!used to remove speckle and create gap between
$!									!final void mask and adjacent trabeculae
$! ---------
$! Show Info
$! ---------
$!
$ set noverify
$ write sys$output ""
$ write sys$output "AIM File:           ''p1'"
$ write sys$output ""
$ write sys$output ""
$!
$!!==================================================
$! SKIP generating the voidspace if already created
$!
$! GOTO STEP_2
$! GOTO STEP_3
$!
$!!==================================================
$!
$ ON ERROR THEN EXIT
$ ipl_batch

/db_scanco_activate false


!
!==========================================================================
!
! STEP 1: Extract Void Space
!
!==========================================================================
!

! -------------------
! Load segmented aim  
! -------------------


/read in seg_filename

/gobj_maskaimpeel_ow
  -input_output             in
  -gobj_filename            mask_filename
  -peel_iter                0

/set_value in 127 0

! ---------------------------------
! Remove small disconnected bone
! ---------------------------------

/cl_nr_extract
  -input                   in
  -output                  bone
  -min_number		     		"misc_param
  -max_number		     		0
  -value_in_range         	127



! ---------------------------------
! Fill in normal trabecular spacing
! ---------------------------------


/dilation
  -input                    bone
  -output                   bone_fill
  -dilate_distance          "tbsp_fill
  -continuous_at_boundary   1 1 1
  -use_previous_margin      false
  -metric   		     		 11	

/erosion
  -input                    bone_fill
  -output                   bone_mask
  -erode_distance 	     	"tbsp_fill
  -use_previous_margin      true
  -metric   		     	 	 11	

/delete in
/delete bone_fill
/delete bone

! --------------------------
! Extract bone void space
! --------------------------

!flip image

/set_value bone_mask 0 127


!erode so that a gap exists between void space volume and adjacent trabeculae

/erosion
  -input                    bone_mask
  -output                   void
  -erode_distance 	     	 "misc_param
  -use_previous_margin      false
  -metric   		     		 11

!mask to remove dilation outside bone boundaries

/gobj_maskaimpeel_ow
 -input_output              void
 -gobj_filename             mask_filename
 -peel_iter                 0

/delete bone_mask


! --------------------------------------
! Extract only very large bone voids
! --------------------------------------

/cl_nr_extract
 -input 	             		 void
 -output                    final_void
 -min_number                "min_void_vol
 -max_number                0
 -value_in_range            127

/write final_void void_filename

/delete void
/delete final_void
!Exit IPL
..
$ ON ERROR THEN EXIT
$!
$ STEP_2:
$!
$!==========================================================================
$!
$! STEP 2: Evaluate Void Space Volume
$!
$!==========================================================================
$!
$ TYPE SYS$INPUT
  !-------------------------------
  ! Void Space to Total Volume Ratio VS/TV [%]
  ! Void Space Volume VS.V [mm^3]
  ! Number of Void Spaces VS.N [#]
  ! Void Space Area VS.Ar [mm^2]
  !-------------------------------
$ IPL_BATCH

/db_scanco_activate false


/read final_void void_filename

/copy final_void trab_void
/copy final_void cort_void

!! VS.N and VS.V
/cl_image
 -input 		     				 final_void
 -output	             		 final_void_cl
 -histofile_or_screentab    screen

/delete final_void_cl


!! Tt.VS/TV
/gobj_maskaimpeel_ow
  -input_output             final_void
  -gobj_filename            mask_filename
  -peel_iter                0 

/vox_scanco_param	     	final_void	


!! Tt.VS.Ar
/moment2d_of_inertia
  -input                    final_void
  -fileout_or_screentab     screen
  -turnangle_cw             0.000000
  -gobj_filename            mask_filename
  -peel_iter                0

!! Tb.VS/TV
/gobj_maskaimpeel_ow
  -input_output             trab_void
  -gobj_filename            trab_mask_filename
  -peel_iter                0 

/vox_scanco_param	     	trab_void

!! Tb.VS.Ar
/moment2d_of_inertia
  -input                    trab_void
  -fileout_or_screentab     screen
  -turnangle_cw             0.000000
  -gobj_filename            trab_mask_filename
  -peel_iter 
  

!! cortical bone

!! Ct.VS/TV
/gobj_maskaimpeel_ow
  -input_output             cort_void
  -gobj_filename            cort_mask_filename
  -peel_iter                0 

/vox_scanco_param	     	cort_void

/delete whole_bone_void
/delete trab_void
/delete cort_void

!Exit IPL
..
$ ON ERROR THEN EXIT
$!
$ STEP_3:
$!
$!==========================================================================
$!
$! STEP 3: Visualize Void Space Volume in Bone
$!
$!==========================================================================
$!
$ TYPE SYS$INPUT
  !-------------------------------
  ! Visualize Bone and voidspace
  !-------------------------------
$ IPL_BATCH

/db_scanco_activate false


!read in segmented bone

/read bone seg_filename

/gobj_maskaimpeel_ow
  -input_output             bone
  -gobj_filename            mask_filename
  -peel_iter                0

/set_value bone -1 0

/read void_aim void_filename

/set_value void_aim 127 0


/concat
  -input1                   bone
  -input2                   void_aim
  -output                   void_combi
  -common_region_only       false
  -add_not_overlay          false
  -make_edge                false
  -shift_ofin2              0 0 0
  -turnangle                0.000000
  -turnpoint_global         -1 -1

!/add_aims
! -input1                    out
! -input2                    void_aim
! -output                    void_combi

/write void_combi combi_void_filename


!Exit IPL
..
$ EXIT
