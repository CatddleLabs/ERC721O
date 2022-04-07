# Omnichain Non-Fungible Token (ERC721-O)
A standard interface and implementation for omnichain non-fungible tokens based on ERC721.

## Motivation
After LayerZero comes out, developing based on omnichain token(Token which can traverse round different chains) become a promising choice for many cross-chain projects. Though it's hardly find a good token standard for omnichain non-fungible tokens. Caveats hide in the LayerZero message mechanism. Implementation without prudence can cause severe fund loss. To minimize the chances of security issues and improve performance, omnichain non-fungible token standard comes up.

Notice: Contracts in this project are no audit and still under develop. Catddle Labs is not liable for any outcomes as a result of using ERC721-O. DYOR.

## Requirements
[hardhat](https://hardhat.org/tutorial/setting-up-the-environment.html)


## Quickstart

```
npx hardhat compile
npx hardhat test
```

## Usage

```
import "./ERC721O.sol";

contract YourToken is ERC721O {
    constructor(address layerZeroEndpoint_)
        ERC721O("Catddle", "CAT", layerZeroEndpoint_)
    {}

    ...
}
```

## Contributing
As an open source project aimed to build omnichain NFT better, any contrbutions are greatly appreciated!
If you have suggestions on the specific code part, you can simply open an issue or create a pull request.

To create a pull request:

1. Fork the Project
2. Create your Feature Branch (git checkout -b feature/AmazingFeature)
3. Commit your Changes (git commit -m 'Add some AmazingFeature')
4. Push to the Branch (git push origin feature/AmazingFeature)
5. Open a Pull Request

## Roadmap

* Fix potential bugs
* Imporve protocol design
* Introduce batch move function
* Introduce multiple chain broadcast function
* Adding ERC721A support
* Adding ERC1155 support

## License
Distributed under the MIT License except the LayerZeroLab parts. Check the SPDX-License headers above each file.
