//
//  RCTBLEManager.m
//  Healthmonitor
//
//  Created by stplmacmini7 on 12/2/15.
//  Copyright (c) 2015 Facebook. All rights reserved.
//

#import "SMBLEManager.h"
#import "RCTBridge.h"
#import "RCTEventDispatcher.h"
#import <CoreBluetooth/CoreBluetooth.h>

static NSString *characteristicUUID;
static NSString *serviceUUID;

@interface SMBLEManager () <CBCentralManagerDelegate, CBPeripheralDelegate>

@property (strong, nonatomic) CBCentralManager      *centralManager;
@property (strong, nonatomic) CBPeripheral          *discoveredPeripheral;
@property (strong, nonatomic) NSMutableData         *data;
@property (strong, nonatomic) NSArray               *servicesArray;
@property (strong, nonatomic) NSArray               *characteristicArray;

@end


@implementation SMBLEManager

RCT_EXPORT_MODULE();

@synthesize bridge = _bridge;

RCT_EXPORT_METHOD(initParameters:(NSString *)service :(NSString *)characteristic)
{
  characteristicUUID = characteristic;
  serviceUUID = service;
  NSLog(@"Service ID : %@ Characteristic ID : %@",serviceUUID,characteristicUUID);
  // Start up the CBCentralManager
  _centralManager = [[CBCentralManager alloc] initWithDelegate:self queue:nil];
  
  //Store the incoming data in _data.
  _data = [[NSMutableData alloc] init];
  _servicesArray = [[NSArray alloc] initWithObjects:[CBUUID UUIDWithString:serviceUUID], nil];
  _characteristicArray = [[NSArray alloc] initWithObjects:[CBUUID UUIDWithString:characteristicUUID], nil];
}

- (void)centralManagerDidUpdateState:(CBCentralManager *)central
{
  if (central.state != CBCentralManagerStatePoweredOn) {
    //Deal with othre states as well : CBCentralManagerStateResetting,CBCentralManagerStateUnsupported,CBCentralManagerStateUnauthorized,CBCentralManagerStatePoweredOff,CBCentralManagerStatePoweredOn,
    NSLog(@"Returning.. Power is not on..");
    return;
    }
  // Start scanning
  [self scan];
  
}

// Scan for peripherals - specifically for our service's 128bit CBUUID
- (void)scan
{
  [self.centralManager scanForPeripheralsWithServices:_servicesArray options:@{ CBCentralManagerScanOptionAllowDuplicatesKey : @YES }];
  
  NSLog(@"Scanning started");
}

/** This callback comes whenever a peripheral that is advertising the TRANSFER_SERVICE_UUID is discovered.
 *  We check the RSSI, to make sure it's close enough that we're interested in it, and if it is,
 *  we start the connection process
 */
- (void)centralManager:(CBCentralManager *)central didDiscoverPeripheral:(CBPeripheral *)peripheral advertisementData:(NSDictionary *)advertisementData RSSI:(NSNumber *)RSSI
{
  // Reject any where the value is above reasonable range
  if (RSSI.integerValue > -15) {
    return;
  }
  
  // Reject if the signal strength is too low to be close enough (Close is around -22dB)
  if (RSSI.integerValue < -35) {
    return;
  }
  
  NSLog(@"Discovered %@ at %@", peripheral.name, RSSI);
  
  // Ok, it's in range - have we already seen it?
  if (self.discoveredPeripheral != peripheral) {
    
    // Save a local copy of the peripheral, so CoreBluetooth doesn't get rid of it
    self.discoveredPeripheral = peripheral;
    
    // And connect
    NSLog(@"Connecting to peripheral %@", peripheral);
    [self.centralManager connectPeripheral:peripheral options:nil];
  }
}

//Scenario for the lost/failed connection.
- (void)centralManager:(CBCentralManager *)central didFailToConnectPeripheral:(CBPeripheral *)peripheral error:(NSError *)error
{
  NSLog(@"Failed to connect to %@. (%@)", peripheral, [error localizedDescription]);
  [self cleanup];
}

/** We've connected to the peripheral, now we need to discover the services and characteristics to find the 'transfer' characteristic.
*/
- (void)centralManager:(CBCentralManager *)central didConnectPeripheral:(CBPeripheral *)peripheral
{
  NSLog(@"Peripheral Connected");
  
  // Stop scanning
  [self.centralManager stopScan];
  NSLog(@"Scanning stopped");
  
  // Clear the data that we may already have
  [self.data setLength:0];
  
  // Make sure we get the discovery callbacks
  peripheral.delegate = self;
  
  // Search only for services that match our UUID
  [peripheral discoverServices:_servicesArray];
}

#pragma mark - Peripheral Method

/** The Transfer Service was discovered.
 */
- (void)peripheral:(CBPeripheral *)peripheral didDiscoverServices:(NSError *)error
{
  if (error) {
    NSLog(@"Error discovering services: %@", [error localizedDescription]);
    [self cleanup];
    return;
  }
  
  // Discover the characteristic we want...
  
  // Loop through the newly filled peripheral.services array, just in case there's more than one.
  for (CBService *service in peripheral.services) {
    [peripheral discoverCharacteristics:_characteristicArray forService:service];
  }
}



- (void)peripheral:(CBPeripheral *)peripheral didDiscoverCharacteristicsForService:(CBService *)service error:(NSError *)error
{
  // Deal with errors (if any)
  if (error) {
    NSLog(@"Error discovering characteristics: %@", [error localizedDescription]);
    [self cleanup];
    return;
  }
  
  // Again, we loop through the array, just in case.
  for (CBCharacteristic *characteristic in service.characteristics) {
    
    // And check if it's the right one
    if ([characteristic.UUID isEqual:[CBUUID UUIDWithString:@"2A37"]]) {
      
      // If it is, subscribe to it
      [peripheral setNotifyValue:YES forCharacteristic:characteristic];
    }
  }
  
  // Once this is complete, we just need to wait for the data to come in.
}

/** This callback lets us know more data has arrived via notification on the characteristic
 */
- (void)peripheral:(CBPeripheral *)peripheral didUpdateValueForCharacteristic:(CBCharacteristic *)characteristic error:(NSError *)error
{
  if (error) {
    NSLog(@"Error discovering characteristics: %@", [error localizedDescription]);
    return;
  }
  
  NSString *stringFromData = [[NSString alloc] initWithData:characteristic.value encoding:NSUTF8StringEncoding];
  
  // Have we got everything we need?
  if ([stringFromData isEqualToString:@"EOM"]) {
    
    // We have, so show the data,
    //[self.textview setText:[[NSString alloc] initWithData:self.data encoding:NSUTF8StringEncoding]];
    
    // Cancel our subscription to the characteristic
    [peripheral setNotifyValue:NO forCharacteristic:characteristic];
    
    // and disconnect from the peripehral
    [self.centralManager cancelPeripheralConnection:peripheral];
  }
  
  // Otherwise, just add the data on to what we already have
  [self.data appendData:characteristic.value];
    
  // Log it
  [self getHeartBPMData:characteristic error:error];
  NSLog(@"Received: %@", stringFromData);
}


/** The peripheral letting us know whether our subscribe/unsubscribe happened or not
 */
- (void)peripheral:(CBPeripheral *)peripheral didUpdateNotificationStateForCharacteristic:(CBCharacteristic *)characteristic error:(NSError *)error
{
  if (error) {
    NSLog(@"Error changing notification state: %@", error.localizedDescription);
  }
  
  // Exit if it's not the transfer characteristic
  if (![characteristic.UUID isEqual:[CBUUID UUIDWithString:@"2A37"]]) {
    return;
  }
  
  // Notification has started
  if (characteristic.isNotifying) {
    NSLog(@"Notification began on %@", characteristic);
  }
  
  // Notification has stopped
  else {
    // so disconnect from the peripheral
    NSLog(@"Notification stopped on %@.  Disconnecting", characteristic);
    [self.centralManager cancelPeripheralConnection:peripheral];
  }
}

/** Once the disconnection happens, we need to clean up our local copy of the peripheral
 */
- (void)centralManager:(CBCentralManager *)central didDisconnectPeripheral:(CBPeripheral *)peripheral error:(NSError *)error
{
  NSLog(@"Peripheral Disconnected");
  self.discoveredPeripheral = nil;
  
  // We're disconnected, so start scanning again
  [self scan];
}



/** When things either go wrong, or you're done with the connection.
 *  This cancels any subscriptions if there are any, or straight disconnects if not.
 *  (didUpdateNotificationStateForCharacteristic will cancel the connection if a subscription is involved)
 */
- (void)cleanup
{
  // Don't do anything if we're not connected
  if (!self.discoveredPeripheral.isConnected) {
          return;
  }
  
  // See if we are subscribed to a characteristic on the peripheral
  if (self.discoveredPeripheral.services != nil) {
    for (CBService *service in self.discoveredPeripheral.services) {
      if (service.characteristics != nil) {
        for (CBCharacteristic *characteristic in service.characteristics) {
          if ([characteristic.UUID isEqual:[CBUUID UUIDWithString:@"2A37"]]) {
            if (characteristic.isNotifying) {
              // It is notifying, so unsubscribe
              [self.discoveredPeripheral setNotifyValue:NO forCharacteristic:characteristic];
              
              // And we're done.
              return;
            }
          }
        }
      }
    }
  }
  
  // If we've got this far, we're connected, but we're not sub scribed, so we just disconnect
  [self.centralManager cancelPeripheralConnection:self.discoveredPeripheral];
}

#pragma mark - Measurement Method

- (void)getHeartBPMData:(CBCharacteristic *)characteristic error:(NSError *)error
{
  // Get the Heart Rate Monitor BPM
  NSData *data = [characteristic value];      // 1
  const uint8_t *reportData = [data bytes];
  uint16_t bpm = 0;
  
  if ((reportData[0] & 0x01) == 0) {          // 2
    // Retrieve the BPM value for the Heart Rate Monitor
    bpm = reportData[1];
  }
  else {
    bpm = CFSwapInt16LittleToHost(*(uint16_t *)(&reportData[1]));  // 3
  }
  // Display the heart rate value to the UI if no error occurred
  if( (characteristic.value)  || !error ) {   // 4
    NSLog(@"Heartbeat --> %d", bpm);
    //NSNumber *dataNumber = [NSNumber numberWithInt:bpm];
    NSString *dataValue = [NSString stringWithFormat:@"%d",bpm];
    [self.bridge.eventDispatcher sendAppEventWithName:@"receivedBLEData"
                                                 body:@{@"value": dataValue}];
    
//    [self.bridge.eventDispatcher sendDeviceEventWithName:@"receivedBLEData"
//                                                body:@{@"name": @"Vishal"}];
    //callback(@[[NSNull null], [NSNumber numberWithInt:bpm]]);
  }
  return;
}



@end
