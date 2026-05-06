Offline Era

Offline Erais a cross-platform, privacy-first LAN communication tool that enables real-time messaging, file sharing, and clipboard synchronization between devices without using the internet or any cloud services**.

It works entirely within a local network (WiFi/LAN)* making it fast, secure, and independent.

Core Idea
Modern apps rely on cloud servers, accounts, and external infrastructure.

Offline Era removes all of that.

If two devices are on the same network, they can discover each other and communicate instantly.

- No login  
- No servers  
- No data leaves your network  

Architecture

 Device Discovery (UDP)
- Devices broadcast their presence over LAN
- Other devices listen and build a live list
- Each device is identified by a display name or device name

 Communication (WebSockets / TCP)
- Direct connection between devices
- Enables real-time messaging, clipboard sync, and file transfer

 Peer-to-Peer
- No central server
- Devices communicate directly

 Features

Real-Time Messaging
- Instant chat between devices
- Low latency (local network)

Auto Device Discovery
- Automatically detects nearby devices
- Live updating device list

 Shared Clipboard
- Copy text/code on one device
- Access it instantly on another

 Code Sharing
- Share code snippets across devices
- Optimized for quick workflows

 File Transfer
- Send files directly over LAN
- Fast and reliable (no cloud relay)

 Notifications
- Alerts for incoming messages and files


 File Handling

When a file is received:

1. File bytes are received over the network  
2. The file is written to local storage  
3. Storage location depends on platform:

- Android → App directory / Downloads  
- macOS → Documents / Downloads  

> Note: File opening and path visibility improvements are in progress.


Privacy

- 100% local communication  
- No cloud usage  
- No external APIs  
- No accounts  

All data stays within your network.

---
Tech Stack

- Flutter (Cross-platform UI)
- Dart (Core logic)
- UDP (Device discovery)
- WebSockets / TCP (Communication)
- Local storage APIs (File handling)

Status

Completed
- LAN device discovery
- Real-time messaging
- Clipboard sync
- Code sharing
- File transfer

In Progress
- File open handling
- Storage path visibility
- UI improvements
- Encryption layer

---

Vision

Offline Era aims to be a modern alternative to LAN tools like IP Messenger, with:

- Better UI
- Cross-platform support
- Strong focus on privacy
- Built for developers (code + clipboard)

---
Philosophy

> Local network is enough.

No internet. No cloud. Just devices communicating directly.
