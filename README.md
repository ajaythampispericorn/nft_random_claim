# RANDOM NFT CLAIMING IN MOVE  

## Overview  
This Move module implements a random NFT claiming mechanism using Aptos randomness. Users can claim a random NFT from a predefined collection, and once all NFTs are claimed, no more can be minted. The module includes admin controls for adding NFTs and event logging for tracking minting events.  

## Features  

* NFT Collection Management: Admins can add NFTs with metadata (name, description, and URI)  
* Random NFT Claiming: Users can claim an NFT randomly from the available collection  
* Event Logging: Minting events are logged with timestamps  
* Global Storage: NFTs are stored in a Collection struct with a total supply cap  
* Helper Functions: Query total supply, minted NFTs, and NFT details  

## Error Codes  
1. NFT_ALREADY_EXISTS (1): The NFT ID already exists  
2. NFT_DOES_NOT_EXIST (2): The requested NFT ID does not exist
3. NOT_OWNER (3): The caller is not the owner of the NFT
4. COLLECTION_NOT_INITIALIZED (4): The NFT collection has not been initialized  
5. ALL_TOKENS_CLAIMED (5): All NFTs have been claimed  

## Pre-Requisites  

* APTOS CLI  

## Installation  

### APTOS CLI  

Go to Aptos [CLI release page](https://github.com/aptos-labs/aptos-core/releases?q=cli&expanded=true)  
Follow the instructions given to install Aptos CLI  

To verify installation,  
```  
aptos --version  
```  

## Setup CLI Configuration  

1. Run the command  
```
aptos init  
```  

To use default settings, you can provide no input and just press “Enter”.  

## Installation  

1. Clone the repository  
```  
git clone https://github.com/ajaythampispericorn/nft_random_claim  
```  

2. Navigate to project directory  
```  
cd nft_random_claim  
```  

## Compiling AND Testing  

```
aptos move compile  

aptos move test   
```  

