//SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "@openzeppelin/contracts/access/AccessControlEnumerable.sol";

contract Barter is IERC721Receiver, AccessControlEnumerable {
    // struct for what each person owes to the seller, specific to what they bought, and when
    struct userBorrow {
        uint256 amountOwed;
        address buyer;
        address seller;
        uint256 timestamp;
    }
    //track how much a wallet has borrowed agsint all thier NFTs
    mapping(address => uint256) totalborrowedETH;

    // mapping: buyer -> NFT Contract -> tokenID -> struct(money owed, buyer, seller, purchase time)
    mapping(address => mapping(address => mapping(uint256 => userBorrow)))
        public loanTracker;

    //Rinkeby WETH contract address
    address public constant WETH = 0xc778417E063141139Fce010982780140Aa0cD5Ab;

    address owner;

    constructor() {
        owner = msg.sender;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "must have owner role");
        _;
    }

    ///@notice function transfers ownership from buyer to seller
    ///@dev the calling contract/function must approve the transfer to the seller's address
    function exchangeNFT(
        address _buyer,
        address _seller,
        address _contract,
        uint256 _tokenID
    ) public {
        /*
    * Security:
    * ower must approve this contract to move thier NFT so even if
    someone else calls this function, it only works if user pre-approved it
    */

        IERC721(_contract).safeTransferFrom(_buyer, _seller, _tokenID);
    }

    ///@notice function transfers ownership from buyer to this contract to be held as collateral
    ///@notice buyer will automaticall receive thier NFT back once they repay the item value
    ///@dev the calling contract/function must approve the transfer to this contract address

    // backend should check to see if there is enough collateral value, it will also allow user to buy multiple items against one NFT
    function collateralizedPurchase(
        address _buyer,
        address _seller,
        address _contract,
        uint256 _tokenID,
        uint256 _itemValue
    ) public {
        /*
        * Security:
        * ower must approve this contract to move thier NFT so even if
        someone else calls this function, it only works if user pre-approved it
        * Only the initial buyer will recieve the NFT on repayment
        */

        //if they purchsed from new seller with same NFT, they must have payed off thier old debts
        if (loanTracker[_buyer][_contract][_tokenID].seller != _seller) {
            require(loanTracker[_buyer][_contract][_tokenID].amountOwed == 0);
        }

        if (loanTracker[_buyer][_contract][_tokenID].timestamp == 0) {
            loanTracker[_buyer][_contract][_tokenID].timestamp = block
                .timestamp;
        } // could also check for default here, but issues may arise, better to have default manually called

        IERC721(_contract).safeTransferFrom(_buyer, address(this), _tokenID);

        loanTracker[_buyer][_contract][_tokenID].amountOwed += _itemValue;
        totalborrowedETH[_buyer] += _itemValue;
        loanTracker[_buyer][_contract][_tokenID].seller = _seller;
        loanTracker[_buyer][_contract][_tokenID].buyer = _buyer;
    }

    ///@notice a user pays back a debt in WETH only and original buyer recieves ERC721
    ///@dev the calling contract/function must approve the transfer of ERC20 to the contract address
    function repay(
        address _buyer,
        address _contract,
        uint256 _tokenID,
        uint256 _amount
    ) public {
        //make sure user has enough WETH
        require(
            IERC20(WETH).balanceOf(msg.sender) >= _amount,
            "not enough WETH to repay"
        );
        require(
            loanTracker[_buyer][_contract][_tokenID].amountOwed >= _amount,
            "Cannot pay back more than you owe"
        );

        IERC20(WETH).transferFrom(
            msg.sender,
            (loanTracker[msg.sender][_contract][_tokenID].seller),
            _amount
        );

        loanTracker[_buyer][_contract][_tokenID].amountOwed -= _amount; //minimum( _amount, loanTracker[_buyer][_contract][_tokenID].amountOwed)
        totalborrowedETH[_buyer] -= _amount;

        //send NFT if debt is paid
        if (loanTracker[_buyer][_contract][_tokenID].amountOwed == 0) {
            IERC721(_contract).safeTransferFrom(
                address(this),
                loanTracker[_buyer][_contract][_tokenID].buyer,
                _tokenID
            );
            //reset struct values:
            loanTracker[_buyer][_contract][_tokenID].timestamp = 0;
            loanTracker[_buyer][_contract][_tokenID].buyer = address(0);
            loanTracker[_buyer][_contract][_tokenID].seller = address(0);
        }
    }

    ///@notice upon defualt, the store gets th NFT, and the user no longer owes money.
    function handleDefault(
        address _buyer,
        address _contract,
        uint256 _tokenID
    ) public onlyOwner {
        /*
         * Security:
         * Only owner can call this right now
         * Can only be called 30 days after first purchase
         */
        require(
            block.timestamp >
                (loanTracker[_buyer][_contract][_tokenID].timestamp + 2592000),
            "Buyer has minumum 30 days to repay"
        );

        IERC721(_contract).safeTransferFrom(
            address(this),
            loanTracker[_buyer][_contract][_tokenID].seller,
            _tokenID
        );
        //reset mapping values
        loanTracker[_buyer][_contract][_tokenID].amountOwed = 0;
        loanTracker[_buyer][_contract][_tokenID].timestamp = 0;
        loanTracker[_buyer][_contract][_tokenID].buyer = address(0);
        loanTracker[_buyer][_contract][_tokenID].seller = address(0);
    }

    function onERC721Received(
        address,
        address,
        uint256,
        bytes memory
    ) public virtual override returns (bytes4) {
        return this.onERC721Received.selector;
    }

    //_____________________________Helper Functions Begin Here_____________________________//

    // function minimum(uint256 a, uint256 b) internal pure returns (uint256) {
    //     return a.min(b);
    // }

    ///@notice returns the total eth quantity owed by a user
    function totalValueBorrowed(address _buyer) public view returns (uint256) {
        return totalborrowedETH[_buyer];
    }

    ///@notice returns value owed on a specific NFT used as collateral
    function valueBorrowedOneNFT(
        address _buyer,
        address _contract,
        uint256 _tokenID
    ) public view returns (uint256) {
        return loanTracker[_buyer][_contract][_tokenID].amountOwed;
    }

    ///@notice returns address of seller who has an NFT as collateral
    function sellerCollateralNFT(
        address _buyer,
        address _contract,
        uint256 _tokenID
    ) public view returns (address) {
        return loanTracker[_buyer][_contract][_tokenID].seller;
    }

    function emergencyExit(address _contract, uint256 _tokenID)
        public
        onlyOwner
    {
        IERC721(_contract).safeTransferFrom(
            address(this),
            msg.sender,
            _tokenID
        );
    }
}
