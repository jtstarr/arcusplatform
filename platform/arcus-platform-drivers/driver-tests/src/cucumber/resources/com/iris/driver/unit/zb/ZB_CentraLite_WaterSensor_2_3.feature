@Zigbee @CentraLite @Leak
Feature: Test of the CentraLite Water Sensor ZigBee driver

    These scenarios test the functionality of the CentraLite Water Sensor ZigBee driver.

    Background:
        Given the ZB_CentraLite_WaterSensor_2_3.driver has been initialized
            And the device has endpoint 1

    @basic
    Scenario: Driver reports capabilities to platform.
        When a base:GetAttributes command is placed on the platform bus
        Then the driver should place a base:GetAttributesResponse message on the platform bus
            And the message's base:caps attribute list should be [ 'base', 'dev', 'devadv', 'devconn', 'devpow', 'leakh2o', 'temp', 'devota', 'ident' ]
            And the message's dev:devtypehint attribute should be Water Leak
            And the message's devadv:drivername attribute should be ZBCentraLiteWaterSensor 
            And the message's devadv:driverversion attribute should be 2.3
            And the message's devpow:source attribute should be BATTERY
            And the message's devpow:linecapable attribute should be false
            And the message's devpow:backupbatterycapable attribute should be false
            And the message's leakh2o:state attribute should be SAFE
        Then both busses should be empty

############################################################
# General Driver Tests
############################################################

    @basic @added @timeout
    Scenario: Device added
        When the device is added
        Then the driver should set timeout at 195 minutes
        Then the capability devpow:sourcechanged should be recent
            And the capability leakh2o:statechanged should be recent

    @basic @name
    Scenario Outline: Make sure driver allows device name to be set 
        When a base:SetAttributes command with the value of dev:name <value> is placed on the platform bus
        Then the platform attribute dev:name should change to <value>

        Examples:
          | value                    |
          | Water                    |
          | "Bathroom Sink"          |
          | "Sue's Sink"             |
          | "Mom & Dad's Bathroom"   |


############################################################
# IAS Zone Cluster Tests
############################################################

    @IASZone
    Scenario Outline: Zone attribute reading and reporting
        Given the capability leakh2o:state is <prevState>
         When the device response with iaszone <messageType> 
          And with parameter ATTR_ZONE_STATUS <zoneStatus>
          And send to driver
         Then the capability leakh2o:state should be <contact> 
          And the capability leakh2o:statechanged should be recent 
          And the driver should place a base:ValueChange message on the platform bus 

    Examples:
    | messageType               | prevState | zoneStatus | contact   |
    | zclreadattributesresponse | LEAK      | 0          | SAFE      |
    | zclreportattributes       | LEAK      | 0          | SAFE      |
    | zclreadattributesresponse | SAFE      | 1          | LEAK      |
    | zclreportattributes       | SAFE      | 1          | LEAK      |
    
    
    @IASZone
    Scenario: iaszone zone enroll request
         When the device response with iaszone zoneenrollrequest 
          And with parameter zoneType 1
          And with parameter manufacturerCode 1
          And send to driver
         Then the driver should send iaszone zoneEnrollResponse
          And with parameter enrollResponseCode 0x00
          And with parameter zoneId 0xFF
    

    @IASZone
    Scenario Outline: iaszone zone status change notification
        Given the capability leakh2o:state is <prevState>
         When the device response with iaszone zonestatuschangenotification 
          And with parameter zoneStatus <zoneStatus>
          And send to driver
         Then the capability leakh2o:state should be <contact> 
          And the capability leakh2o:statechanged should be recent 
          And the driver should place a base:ValueChange message on the platform bus 

    Examples:
    | messageType                  | prevState | zoneStatus | contact |
    | zonestatuschangenotification | LEAK      | 0          | SAFE    |
    | zonestatuschangenotification | SAFE      | 1          | LEAK    |
    

############################################################
# Power Cluster Tests
############################################################

    @Power
    Scenario Outline: Power Read / Report
        Given the capability devpow:battery is 90
        When the device response with power <messageType> 
            And with parameter ATTR_BATTERY_VOLTAGE <voltage>
            And with parameter ATTR_BATTERY_VOLTAGE_MIN_THRESHOLD 21
            And send to driver
        Then the driver should place a base:ValueChange message on the platform bus
            And the message's devpow:battery attribute numeric value should be within delta 1.1 of <battery>
    
    Examples:
      | messageType               | voltage | battery | remarks                 |
      | zclreadattributesresponse | 0       | 90      | ignore invalid 0 values |
      | zclreadattributesresponse | 20      | 0       | below min should be 0   |
      | zclreadattributesresponse | 21      | 0       |                         |
      | zclreportattributes       | 25      | 44      |                         |
      | zclreportattributes       | 30      | 100     |                         |
      | zclreportattributes       | 31      | 100     | above max should be 100 |


############################################################
# Poll Control Cluster Tests
############################################################

    @Poll
    Scenario Outline: poll control read / report
        When the device response with pollcontrol <messageType>
        And with parameter ATTR_CHECKIN_INTERVAL 1
        And with parameter ATTR_LONG_POLL_INTERVAL 1
        And with parameter ATTR_SHORT_POLL_INTERVAL 1
        And send to driver

    Examples:
      | messageType               |
      | zclreadattributesresponse |
      | zclreportattributes       |

    @Poll
    Scenario: poll control check in
        When the device response with pollcontrol checkin
            And send to driver
        Then the driver should send pollcontrol checkinresponse    
    
############################################################
# Temperature Cluster Tests
############################################################

    @Temperature
    Scenario Outline: Temperature measurement attribute reading and reporting
        When the device response with temperaturemeasurement <responseType>
            And with parameter ATTR_MEASURED_VALUE <value>
            And send to driver
        Then the driver should place a base:ValueChange message on the platform bus
            And the message's temp:temperature attribute numeric value should be within delta 0.01 of <result>

    Examples:
      | responseType              | value | result |
      | zclreadattributesresponse | 2757  | 27.57  |
      | zclreportattributes       | 2757  | 27.57  |


############################################################
# Diagnostics Cluster Tests
############################################################

    @Diagnostics
    Scenario Outline: diagnostics read / report response
        When the device response with diagnostics <messageType>
            And with parameter ATTR_LAST_MESSAGE_RSSI <rssi>
            And with parameter ATTR_LAST_MESSAGE_LQI <lqi>
            And send to driver
        Then the capability devconn:signal should be <signal> 
    
    Examples:
      | messageType               | rssi | lqi      | signal |
      | zclreadattributesresponse | 10   | 10       | 4      |
      | zclreportattributes       | 10   | INVALID  | 100    |


############################################################
# OTA Cluster Tests
############################################################

    # ota.zclreadattributesresponse
    @OTA
    Scenario: OTA read response
        Given the capability devota:targetVersion is 1
        When the device response with ota zclreadattributesresponse
            And with parameter ATTR_CURRENT_FILE_VERSION 1
            And send to driver
        Then the driver should place a base:ValueChange message on the platform bus
            And the capability devota:currentVersion should be 1
            And the capability devota:status should be COMPLETED
    
    # ota.querynextimagerequest
    @OTA
    Scenario: OTA query next image
        Given the capability devota:targetVersion is 1
        When the device response with ota querynextimagerequest
            And with parameter manufacturerCode 1
            And with parameter imageType 1
            And with parameter fileVersion 1
            And with header flags 1
            And send to driver
        Then the driver should place a base:ValueChange message on the platform bus
            And the capability devota:currentVersion should be 1
            And the capability devota:status should be COMPLETED
    
    #ota.imageblockrequest / imagePageRequest
    @OTA
    Scenario Outline: OTA image block / page
        Given the capability devota:status is IDLE
        When the device response with ota <messageType>
            And with parameter fileVersion 1
            And with parameter fileOffset 0
            And with header flags 1
            And send to driver 
        Then the driver should place a base:ValueChange message on the platform bus
            And the capability devota:targetVersion should be 1
            And the capability devota:status should be INPROGRESS
    
    Examples:
      | messageType       |
      | imageblockrequest |
      | imagePageRequest  |
    
    
    # ota.upgradeendrequest
    @OTA
    Scenario Outline: OTA upgrade end request
        When the device response with ota upgradeendrequest
            And with parameter status <status>
            And with parameter manufacturerCode 0
            And with parameter imageType 0
            And with parameter fileVersion 0
            And with header flags 1
            And send to driver 
        Then the driver should place a base:ValueChange message on the platform bus
            And the capability devota:status should be <result>

    Examples:
      | status | result    |
      |    0   | COMPLETED |
      |   -1   | FAILED    |


############################################################
# ZigBee Ack/Response Message Tests
############################################################

    Scenario Outline: default ZigbeeMessage processing
        When the device response with <cluster> <command>
            And send to driver

    Examples:
      | cluster | command | remarks                                |
      | 0x0001  | 0x07    | CLUSTER_PWR_CNFG,     CMD_CNFG_RPT_RSP |
      | 0x0020  | 0x04    | CLUSTER_POLL_CONTROL, CMD_WRT_ATTR_RSP |
      | 0x0020  | 0x0B    | CLUSTER_POLL_CONTROL, CMD_DFLT_RSP     |
      | 0x0402  | 0x07    | CLUSTER_TEMPERATURE,  CMD_CNFG_RPT_RSP |
      | 0x0500  | 0x0B    | CLUSTER_IAS_ZONE,     CMD_DFLT_RSP     |
      | 0x0B05  | 0x07    | CLUSTER_DIAGNOSTICS,  CMD_CNFG_RPT_RSP |

