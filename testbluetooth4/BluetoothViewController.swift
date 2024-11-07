//
//  BluetoothViewController.swift
//  testbluetooth4
//
//  Created by 洪宗燦 on 2024/10/16.
//
//
//  BluetoothViewController.swift
//  testbluetooth3
//
//  Created by 洪宗燦 on 2024/10/16.
//

import UIKit
import CoreBluetooth

class BluetoothViewController: UIViewController, CBCentralManagerDelegate, CBPeripheralDelegate , UITableViewDelegate, UITableViewDataSource  {
    
    
    @IBOutlet weak var t1MinusT2Value: UITextField!
    @IBOutlet weak var t1Value: UITextField!
    
    @IBOutlet weak var t2Value: UITextField!
    
    @IBOutlet weak var t3Value: UITextField!
    
    @IBOutlet weak var t4Value: UITextField!
    
    
    @IBOutlet weak var sendButton: UIButton!
   
    @IBOutlet weak var textView: UITextView!
   
    @IBOutlet weak var tableView: UITableView!
    var centerManager: CBCentralManager!
    var peripherals: [CBPeripheral] = []
    var selectedPeripheral: CBPeripheral!
    var txCharacteristic: CBCharacteristic!
    var commandTimer: Timer?
    override func viewDidLoad() {
        super.viewDidLoad()
        centerManager = CBCentralManager(delegate: self, queue: nil)
        tableView.delegate = self
        tableView.dataSource = self
        t1Value .font = UIFont(name: "digital-7", size: 16)

        for family: String in UIFont.familyNames {
            print(family)
            for name: String in UIFont.fontNames(forFamilyName: family) {
                print("==   \(name)")
            }
        }
    }
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        if central.state == .poweredOn {
            centerManager.scanForPeripherals(withServices: nil, options: nil)
        } else {
            print("Bluetooth is not available")
        }
    }
    
    
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        if let name = peripheral.name , name.hasPrefix("BT"){
            // 使用 identifier 檢查是否已經加入過此裝置
                if !peripherals.contains(where: { $0.identifier == peripheral.identifier }) {
                    peripherals.append(peripheral)

                    // 在主執行緒更新 UI
                    DispatchQueue.main.async {
                        self.tableView.reloadData()
                        print("Discovered \(name)")
                    }
                } else {
                    print("Device \(name) is already in the list")
                }
            }
        }
    
    
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
            print("Connected to \(peripheral.name ?? "a device")")
            peripheral.delegate = self
            peripheral.discoverServices(nil)
        }
        
        func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
            guard let services = peripheral.services else { return }
            for service in services {
                peripheral.discoverCharacteristics(nil, for: service)
            }
        }
        func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
            if let characteristics = service.characteristics {
                for characteristic in characteristics {
                    print("Characteristic found: \(characteristic.uuid)")
                    if characteristic.properties.contains(.write) {
                        txCharacteristic = characteristic
                    }
                    else if characteristic.properties.contains(.notify) {
                        peripheral.setNotifyValue(true, for: characteristic)
                    }
                }
            }
        }
        
    // 解碼兩個 byte 的通道值並轉換為溫度
    func decodeChannelValue(data: Data, byteIndex: Int) -> Double {
        // 確保索引合法
          guard byteIndex + 1 < data.count else { return 0.0 }
          
          // 讀取兩個 byte，並將它們組合成有號 16 位元整數 (Int16)
          let highByte = Int16(data[byteIndex])
          let lowByte = Int16(data[byteIndex + 1])

          // 將高位元移位，並與低位元相加，形成有號 16 位數值
          let value = (highByte << 8) | lowByte

          // 將數值除以 10，轉為浮點數的結果
          return Double(value) / 10.0
    }
    
    
        func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
            if let data = characteristic.value {
                let hexString = data.map { String(format: "%02x", $0) }.joined(separator: " ")
                let byteCount = data.count
                textView.text =  "Received:\(hexString)\n"
                print("Received data:\(hexString)")
                
                print("Received (\(byteCount) bytes): \(hexString)")
                if data.count == 64 {}
                else {
                      print("Received data is not 64 bytes")
                      return
                  }
                  
                  // 檢查第一個 byte 是否為 0x02，最後一個 byte 是否為 0x03
                  guard data.first == 0x02, data.last == 0x03 else {
                      print("Invalid data format: First byte is not 0x02 or last byte is not 0x03")
                      return
                  }

                  print("Received valid 64-byte data")
                
                
         
       
                    let channel1 = decodeChannelValue(data: data, byteIndex: 9)  // 第 10 和 11 byte
                
                    let channel2 = decodeChannelValue(data: data, byteIndex: 11)  // 第 12 和 13 byte
                    let channel3 = decodeChannelValue(data: data, byteIndex: 13)  // 第 14 和 15 byte
                    let channel4 = decodeChannelValue(data: data, byteIndex: 15)  // 第 16 和 17 byte
                    let t1MinusT2 = decodeChannelValue(data: data, byteIndex: 17) // 第 18 和 19 byte
                
                t1Value.text = String(channel1)
                t2Value.text = String(channel2)
                t3Value.text = String(channel3)
                t4Value.text = String(channel4)
                t1MinusT2Value.text = String(t1MinusT2)
             }
        }
        
    

       // 連接失敗時觸發
       func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
           print("連接失敗：\(error?.localizedDescription ?? "未知錯誤")")
       }
    
    
        func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
            return peripherals.count
        }
        
        func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
            let cell = tableView.dequeueReusableCell(withIdentifier: "PeripheralCell", for: indexPath)
            let peripheral = peripherals[indexPath.row]
            cell.textLabel?.text = peripheral.name
            return cell
        }
        
        func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
            let peripheral = peripherals[indexPath.row]
            selectedPeripheral = peripheral
            centerManager.stopScan()
            
            centerManager.connect(peripheral, options: nil)
        }
   
    @IBAction func maxMin(_ sender: Any) {
        
        guard let peripheral = selectedPeripheral, let txCharacteristic = txCharacteristic else { return }
        
        let bytes: [UInt8] = [0x02, 0x4D, 0x00, 0x00, 0x00, 0x00, 0x03]
        let data = Data(bytes)
        
        peripheral.writeValue(data, for: txCharacteristic, type: .withoutResponse)
        print("Sent data: \(data.map{ String(format: "%02X", $0) }.joined(separator: " "))")
        
    }
    
   
    @IBAction func askModel(_ sender: Any) {
        guard let peripheral = selectedPeripheral, let txCharacteristic = txCharacteristic else { return }
        
        let bytes: [UInt8] = [0x02, 0x4D, 0x00, 0x00, 0x00, 0x00, 0x03]
        let data = Data(bytes)
        
        peripheral.writeValue(data, for: txCharacteristic, type: .withResponse)
        print("Sent data: \(data.map{ String(format: "%02X", $0) }.joined(separator: " "))")
        
        
    }
    /// 每 0.5 秒執行的指令發送邏輯
    @objc func sendRepeatedCommand() {
        let command: [UInt8] = [0x02, 0x41, 0x00, 0x00, 0x00, 0x00, 0x03]
        sendCommand(command)
    }
    
    @IBAction func startTimer(_ sender: Any) {
        commandTimer = Timer.scheduledTimer(timeInterval: 0.5, target: self, selector: #selector(sendRepeatedCommand), userInfo: nil, repeats: true)

    }
    
    
    @IBAction func stopTimer(_ sender: Any) {
        commandTimer?.invalidate()
        commandTimer = nil
    }
    
    
    @IBAction func adkModel(_ sender: Any) {
        let command: [UInt8] = [0x02, 0x4B, 0x00, 0x00, 0x00, 0x00, 0x03]
          sendCommand(command)
    }
    
    @IBAction func sendACommand(_ sender: Any) {
        let command: [UInt8] = [0x02, 0x41, 0x00, 0x00, 0x00, 0x00, 0x03]
          sendCommand(command)

        
    }
    
    @IBAction func reScan(_ sender: Any) {
        stopScanning() // 停止之前的掃描
           scanForBluetoothDevices() // 重新開始掃描
    }
    
    
    @IBAction func sendButtonTapped(_ sender: Any) {
  
    }
    
    @IBAction func disconnect(_ sender: UIButton) {
        guard let peripheral = selectedPeripheral else {
               print("No device is currently connected.")
               return
           }
        centerManager.cancelPeripheralConnection(peripheral)
  
    }
    /// 傳送藍芽資料的通用函數
    /// - Parameter bytes: 要傳送的 Byte 陣列
    func sendCommand(_ bytes: [UInt8]) {
        guard let peripheral = selectedPeripheral, let txCharacteristic = txCharacteristic else {
            print("未找到連接的裝置或特徵值")
            return
        }

        let data = Data(bytes)
        peripheral.writeValue(data, for: txCharacteristic, type: .withResponse)
        print("Sent data: \(data.map { String(format: "%02X", $0) }.joined(separator: " "))")
    }
    
    // MARK: - Bluetooth Scanning

        func scanForBluetoothDevices() {
            // 清空之前的裝置列表並更新 UI
            peripherals.removeAll()
            tableView.reloadData()

            print("Scanning for Bluetooth devices...")
            centerManager.scanForPeripherals(withServices: nil, options: nil)
        }

        func stopScanning() {
            centerManager.stopScan()
            print("Stopped scanning for Bluetooth devices.")
        }

    
}

