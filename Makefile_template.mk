
########################################
#define some VARs
#1.define some name-VARs
MODEL_BUILD=BUILD_MODEL_16BIT
MODEL_TFLITE =BUILD_MODEL_16BIT/body_detection.tflite
MODEL_STATE = body_detection.json
NNTOOL_SCRIPT=
MODEL_NAME=body_detection.tflite
MODEL_SRC=body_detectionModel.c
TENSORS_DIR=${MODEL_BUILD}/tensors
# MODEL_TENSORS = $(MODEL_BUILD)/$(MODEL_PREFIX)_L3_Flash_Const.dat
MODEL_HEADER=body_detectionInfo.h

MODEL_GEN_EXE=./GenTile


#2. define necessary VARs
#1)_SQ8/_POW2
CNN_GEN = $(MODEL_GEN_SQ8/_POW2)
CNN_GEN_INCLUDE = $(MODEL_GEN_INCLUDE_SQ8)
CNN_LIB = $(MODEL_LIB_SQ8)
CNN_LIB_INCLUDE = $(MODEL_LIB_INCLUDE_SQ8)
#2)
QUANTIZATION_BITS=8/16 # use different build folder name
platform=

#3)define FC,L1/L2/L3 memory
FREQ_FC?=250
MODEL_L1_MEMORY=$(shell expr 60000 \- $(TOTAL_STACK_SIZE))
MODEL_L2_MEMORY=200000
MODEL_L3_MEMORY=8388608

MODEL_GEN_EXTRA_FLAGS=--L1 ${MODEL_L1_MEMORY} --L2 ${MODEL_L2_MEMORY} --L3 ${MODEL_L3_MEMORY}


#########################################
#1-4 can be put inside file model_rules.mk
#1. use nntool to generate body_detection.json
#MODEL_STATE = body_detection.json(comes from nntool save state)
$(MODEL_STATE): $(MODEL_TFLITE)  # MODEL_TFLITE =BUILD_MODEL_16BIT/body_detection.tflite
	nntool -s $(NNTOOL_SCRIPT) $(MODEL_BUILD)/$(MODEL_NAME) 
#	nntool -s model/nntool_script16 BUILD_MODEL_16BIT/body_detection.tflite 

#2. use nntool to generate body_detectionModel.c, tensors and body_detectionInfo.h 
# Runs NNTOOL with its state file to generate the autotiler model code
$(MODEL_BUILD)/$(MODEL_SRC): $(MODEL_STATE) $(MODEL_TFLITE) #MODEL_BUILD_16BIT/body_detectionModel.c: MODEL_BUILD_16BIT/body_detection.json(comes from nntool save state)  model/body_detection.tflite
	nntool -g $(MODEL_STATE) -M $(MODEL_BUILD) -m $(MODEL_SRC) -T $(TENSORS_DIR) -H $(MODEL_HEADER) $(MODEL_GENFLAGS_EXTRA)  #?? where is the input_image.
#	nntool -g -M overwrite Model_dir(BUILD_MODEL_16BIT) -m overwrite Model_file(body_detectionModel.c) -T overwrite tensors -H write graph info in body_detectionInfo.h body_detection.json



#3. compile ./GenTile
# Build the code generator from the model code
$(MODEL_GEN_EXE): $(MODEL_BUILD)/$(MODEL_SRC)   #./GenTile: MODEL_BUILD_16BIT/body_detectionModel.c
	gcc -g -o $(MODEL_GEN_EXE) -I. -I$(TILER_INC) -I$(TILER_EMU_INC) $(CNN_GEN_INCLUDE) $(CNN_LIB_INCLUDE) $(MODEL_BUILD)/$(MODEL_SRC) $(CNN_GEN) $(TILER_LIB)
#	gcc -g -o ./GenTile -I. -Igap_sdk... MODEL_BUILD_16BIT/body_detectionModel.c gac_sdk/..tools/autotiler_v3/CNN_Generators/CNN_Generator_Util.c|CNN_Generators.c /gap_sdk/..tools/nntools/autotiler/generators/nntool_extra_generators.c gap_sdk/..tools/autotiler_v3/Autotiler/LibTile.a

#4. ./GenTile will generate body_detectionKernels.c/h
# Run the code generator to generate GAP graph and kernel code
##MODEL_GEN_C = MODEL_BUILD_16BIT/body_detectionKernels.c
#Here ./GenTile generate body_detectionKernels.c/h  automatically
$(MODEL_GEN_C): $(MODEL_GEN_EXE)  #MODEL_GEN_EXE= ./GenTile  inside the  MODEL_BUILD_16BIT/body_detectionModel.c, there is a main() entry to GenerateTilingCode();
	$(MODEL_GEN_EXE) -o $(MODEL_BUILD) -c $(MODEL_BUILD) $(MODEL_GEN_EXTRA_FLAGS)
#	./GenTile -o ${MODEL_BUILD} -c ${MODEL_BUILD} --L1 48736 --L2 200000 --L3 8388608

###############################################


#?? A phony target to simplify including this in the main Makefile
#make run platform=gvsoc? <<===>> main.c?
model: $(MODEL_GEN_C)


# all depends on the model
all:: model

clean::
	rm -rf ${MODEL_BUILD}


# include model_rules.mk
include $(RULES_DIR)/pmsis_rules.mk