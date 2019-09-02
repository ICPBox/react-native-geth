//
//  ReactNativeGeth.swift
//  ReactNativeGeth
//
//  Created by 0mkar on 04/04/18.
//

import Foundation
import Geth

@objc(ReactNativeGeth)
class ReactNativeGeth: RCTEventEmitter, GethNewHeadHandlerProtocol {
    func onError(_ failure: String!) {
        NSLog("@", failure)
    }
    
    private var TAG: String = "Geth"
    private var ETH_DIR: String = ".appintegration"
    private var KEY_STORE_DIR: String = "keystore"
    private let ctx: GethContext
    private var geth_node: NodeRunner
    private var datadir = NSHomeDirectory() + "/Documents"

    override init() {
        self.ctx = GethNewContext()
        self.geth_node = NodeRunner()
        super.init()
    }
    
    @objc(supportedEvents)
    override func supportedEvents() -> [String]! {
        return ["GethNewHead"]
    }
    
    @objc(getName)
    func getName() -> String {
        return TAG
    }
    
    func convertToDictionary(from text: String) throws -> [String: String] {
        guard let data = text.data(using: .utf8) else { return [:] }
        let anyResult: Any = try JSONSerialization.jsonObject(with: data, options: [])
        return anyResult as? [String: String] ?? [:]
    }
    
    func onNewHead(_ header: GethHeader) {
        do {
            let json = try header.encodeJSON()
            let dict = try self.convertToDictionary(from: json)
            self.sendEvent(withName: "GethNewHead", body:dict)
        } catch let NSErr as NSError {
            NSLog("@", NSErr)
        }
    }
    
    /**
     * Creates and configures a new Geth node.
     *
     * @param config  Json object configuration node
     * @param promise Promise
     * @return Return true if created and configured node
     */
    @objc(nodeConfig:resolver:rejecter:)
    func nodeConfig(config: NSObject, resolver resolve: RCTPromiseResolveBlock, rejecter reject: RCTPromiseRejectBlock) -> Void {
        do {
            let nodeconfig: GethNodeConfig = geth_node.getNodeConfig()!
            var nodeDir: String = ETH_DIR
            var keyStoreDir: String = KEY_STORE_DIR
            var error: NSError?
            
            if(config.value(forKey: "enodes") != nil) {
                geth_node.writeStaticNodesFile(enodes: config.value(forKey: "enodes") as! String)
            }
            if((config.value(forKey: "networkID")) != nil) {
                nodeconfig.setEthereumNetworkID(config.value(forKey: "networkID") as! Int64)
            }
            if(config.value(forKey: "maxPeers") != nil) {
                nodeconfig.setMaxPeers(config.value(forKey: "maxPeers") as! Int)
            }
            if(config.value(forKey: "genesis") != nil) {
                nodeconfig.setEthereumGenesis(config.value(forKey: "genesis") as! String)
            }
            if(config.value(forKey: "nodeDir") != nil) {
                nodeDir = config.value(forKey: "nodeDir") as! String
            }
            if(config.value(forKey: "keyStoreDir") != nil) {
                keyStoreDir = config.value(forKey: "keyStoreDir") as! String
            }
            
            nodeconfig.setSyncMode(5)
            
            let node: GethNode = GethNewNode(datadir + "/" + nodeDir, nodeconfig, &error)
            let keyStore: GethKeyStore = GethNewKeyStore(keyStoreDir, GethLightScryptN, GethLightScryptP)
            if error != nil {
                reject(nil, nil, error)
                return
            }
            geth_node.setNodeConfig(nc: nodeconfig)
            geth_node.setKeyStore(ks: keyStore)
            geth_node.setNode(node: node)
            resolve([true] as NSObject)
        } catch let NCErr as NSError {
            NSLog("@", NCErr)
            reject(nil, nil, NCErr)
        }
    }
    
    /**
     * Start creates a live P2P node and starts running it.
     *
     * @param promise Promise
     * @return Return true if started.
     */
    @objc(startNode:rejecter:)
    func startNode(resolver resolve: RCTPromiseResolveBlock, rejecter reject: RCTPromiseRejectBlock) -> Void {
        do {
            var result: Bool = false
            if(geth_node.getNode() != nil) {
                try geth_node.getNode()?.start()
                result = true
            }
            
            resolve([result] as NSObject)
        } catch let NSErr as NSError {
            NSLog("@", NSErr)
            reject(nil, nil, NSErr)
        }
    }
    
    @objc(subscribeNewHead:rejecter:)
    func subscribeNewHead(resolver resolve: RCTPromiseResolveBlock, rejecter reject: RCTPromiseRejectBlock) -> Void {
        do {
            if(geth_node.getNode() != nil) {
                try geth_node.getNode()?.getEthereumClient().subscribeNewHead(self.ctx, handler: self, buffer: 16)
            }
            resolve([true] as NSObject)
        } catch let NSErr as NSError {
            NSLog("@", NSErr)
            reject(nil, nil, NSErr)
        }
    }
    
    /**
     * Terminates a running node along with all it's services.
     *
     * @param promise Promise
     * @return return true if stopped.
     */
    @objc(stopNode:rejecter:)
    func stopNode(resolver resolve: RCTPromiseResolveBlock, rejecter reject: RCTPromiseRejectBlock) -> Void {
        do {
            var result: Bool = false
            if(geth_node.getNode() != nil) {
                try geth_node.getNode()?.stop()
                result = true
            }
            resolve([result] as NSObject)
        } catch let NSErr as NSError {
            NSLog("@", NSErr)
            reject(nil, nil, NSErr)
        }
    }
}
