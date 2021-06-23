#include<stdio.h>

//include sdk head files
#include "Gap.h"
#include "pmsis.h"


//Global defines
struct pi_device HyperRam;
struct pi_hyperram_conf hyper_conf;


static void RunNN()
{
    printf("===RunNN===")
    unsigned int ti,ti_nn;
    gap_cl_starttimer();
    gap_cl_resethwtimer();
    
    ti = gap_cl_readhwtimer();
    body_detectionCNN(ImageIn, Output_1, Output_2, Output_3, Output_4, Output_5, Output_6, Output_7, Output_8);
    ti_nn = gap_cl_readhwtimer()-ti;
    PRINTF("Cycles NN : %10d\n",ti_nn);
}



int start()
{   //main app process
    //1. Initialize & open ram
  	pi_hyperram_conf_init(&hyper_conf);
    pi_open_from_conf(&HyperRam, &hyper_conf);
	if (pi_ram_open(&HyperRam))
	{
		printf("Error ram open !\n");
		pmsis_exit(-3);
	}
    printf("HyperRAM config done\n");

    //2. Allocate l2 for input image
    /*
    read image from camera or host pc
    allocate l2 input image
    */
    unsigned char *ImageInChar = (unsigned char *) pmsis_l2_malloc( W * H * sizeof(MNIST_IMAGE_IN_T));
    ReadImageFromFile(ImageName, &Wi, &Hi, ImageInChar, W * H * sizeof(unsigned char))


    //3. Allocate output buffer
    //This is import for NN run
    
	// ResOut = (NETWORK_OUT_TYPE *) AT_L2_ALLOC(0, NUM_CLASSES*sizeof(NETWORK_OUT_TYPE));
	// if (ResOut==0) {
	// 	printf("Failed to allocate Memory for Result (%ld bytes)\n", 2*sizeof(char));
	// 	return 1;
	// }
    
    pi_ram_alloc(&HyperRam, &Output_1, 60 * 80* 12 * sizeof(short int));


    //4. Configure And open cluster.
    struct pi_device cluster_dev;
    struct pi_cluster_conf cl_conf;
    cl_conf.id = 0; //pi_cluster_conf_init(&conf);
    pi_open_from_conf(&cluster_dev, (void *) &cl_conf);
    if (pi_cluster_open(&cluster_dev))
    {
        printf("Cluster open failed !\n");
        pmsis_exit(-7);
    }


    //5. Network Constructor
	// IMPORTANT: MUST BE CALLED AFTER THE CLUSTER IS ON!
	int err_const = AT_CONSTRUCT();
	if (err_const)
	{
	  printf("Graph constructor exited with error: %d\n", err_const);
	  return 1;
	}
	printf("Network Constructor was OK!\n");


    //6. Task setup
    struct pi_cluster_task *task = pmsis_l2_malloc(sizeof(struct pi_cluster_task));
    if(task==NULL) {
        printf("Alloc Error! \n");
        pmsis_exit(-5);
    }

    memset(task, 0, sizeof(struct pi_cluster_task));
    task->entry = RunNN;
    task->arg = (void *) NULL;
    task->stack_size = (uint32_t) CLUSTER_STACK_SIZE;
    task->slave_stack_size = (uint32_t) CLUSTER_SLAVE_STACK_SIZE;
    //Dispatch task on cluster
    pi_cluster_send_task_to_cl(&cluster_dev, task);
    

    //7. Netwrok Destructor and close cluster
	AT_DESTRUCT();
	pi_cluster_close(&cluster_dev);
    printf("End \n")

    //check results, if not correct pmsis_exit(-1);
	pmsis_exit(0);


    return 0;
    
}



int main(void)
{
    printf("\n\n\t *** NN on GAP ***\n");
    return pmsis_kickoff((void *) start); //start app
}