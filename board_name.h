/*
 * board_name.h
 *
 *  Created on: Sep 25, 2024
 *      Author: İlyas Başaran
 */

#ifndef ARMFWVERSION_BOARD_NAME_H_
#define ARMFWVERSION_BOARD_NAME_H_

#if defined(FAN_CONTROLLER_RECOVERY)
  	#define BOARD_NAME_STR "FAN_CONTROLLER_RECOVERY"
#elif defined(FAN_CONTROLLER)
	#define BOARD_NAME_STR "FAN_CONTROLLER"
#elif defined(FAN_CONTROLLER_TESTER)
	#define BOARD_NAME_STR "FAN_CONTROLLER_TESTER"
#elif defined(RELAY_CONTROLLER_RECOVERY)
	#define BOARD_NAME_STR "RELAY_CONTROLLER_RECOVERY"
#elif defined(RELAY_CONTROLLER)
	#define BOARD_NAME_STR "RELAY_CONTROLLER"
#else
	#error "No valid board type defined!"
#endif

#if defined(V1R1)
	#define BOARD_VERSION_NAME_STR "V1R1"
#elif defined(V1R2)
#define BOARD_VERSION_NAME_STR "V1R2"
#else
	#error "No valid board version type defined!"
#endif

static const char* BOARD_NAME = BOARD_NAME_STR;
static const char* BOARD_VERSION_NAME = BOARD_VERSION_NAME_STR;

#endif /* ARMFWVERSION_BOARD_NAME_H_ */

