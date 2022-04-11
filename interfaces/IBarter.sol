// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

interface InterfaceBarter {
    function exchangeNFT(
        address _buyer,
        address _seller,
        address _collection,
        uint256 _tokenID
    ) external;

    function collateralizedPurchase(
        address _buyer,
        address _seller,
        address _collection,
        uint256 _tokenID,
        uint256 _itemValue
    ) external;

    function repay(
        address _collection,
        uint256 _tokenID,
        uint256 _amount
    ) external;

    function totalValueBorrowed(address _borrower)
        external
        view
        returns (uint256);

    function valueBorrowedOneNFT(
        address _buyer,
        address _collection,
        uint256 _tokenID
    ) external view returns (uint256);
}
