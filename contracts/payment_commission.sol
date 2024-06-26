// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import "hardhat/console.sol";

/**
 * Accept payment
 * Pay the vendor
 * take commission on payment to vendor
 * 
 */
contract GadgetShop {
    struct Product {
        bytes32 id;
        string name;
        string features;
        uint256 price;
        address seller;
        bool bought;
    }
    address public owner;
    mapping (address => uint256) public buyers;
    mapping (address => uint256) public sellers;
    mapping (bytes32 => Product) public products;
    mapping (address => Product) public boughtProduct; // maps buyer to the bought product

    uint256 public commission_rate;
    uint256 public commission_total = 0;
    Product[] public productList;
    event Withdrawal(uint amount, uint when);
    event ProductAdded(address seller, string name, bytes32 id, uint256 price);
    event ProductBought(address buyer, address seller, uint256 commission, string productName, bytes32 id);
    event SellerPaid(address seller, uint256 amount);


    constructor(uint256 rate) {
        owner = msg.sender;
        commission_rate = rate;
    }

    modifier onlyOwner {
        if (msg.sender != owner) {
            revert("You cannot do this!");
        }
        _;
    }


    
    // function withdrawCommission() public onlyOwner {
    //     payable(owner).transfer(commission_total);
    //     emit Withdrawal(commission_total, block.timestamp);
    // }
    function addProduct(string memory name, string memory features, uint256 price, address seller) public {
        bytes32 id = generateID(name, seller);
        Product memory item = Product(id, name, features, price, seller, false);
        products[id] = item;
        productList.push(item);
        emit ProductAdded(seller, name, id, price);
    }
    /**
     * creates a bytes32 array from two strings
     * @param str1 first string
     * @param str2 second string
     */
    function generateID(string memory str1, address str2) public pure returns (bytes32) {
        return(keccak256(abi.encodePacked(str1, str2)));
    }
    function takeCommission(uint256 amount, address seller) internal returns(uint256) {
        uint256 commission = (amount * commission_rate) / 100;
        sellers[seller] += amount - commission;
        commission_total += commission;
        return (commission);
    }
    function buyProduct(bytes32 _id) public payable {
        Product memory item = products[_id];
        if (item.seller != address(0) || item.price == 0) {
            revert ("Product does not exist");
        }
        if (msg.value < item.price) {
            revert("Insufficient funds");
        }
        uint256 commission = takeCommission(msg.value, item.seller);
        products[_id].bought = true;
        boughtProduct[msg.sender] = products[_id];
        emit ProductBought(msg.sender, item.seller, commission, item.name, _id);
    }
    function withdraw() public payable onlyOwner {
        require(address(this).balance > 0, "You should have more money");
        payable(owner).transfer(address(this).balance);
        emit Withdrawal(address(this).balance, block.timestamp);
    }
    function paySeller() public {
        if (sellers[msg.sender] == 0) {
            revert("You are not a seller or we do not have your money");
        }
        payable(address(this)).transfer(sellers[msg.sender]);
        emit SellerPaid(msg.sender, sellers[msg.sender]);
        sellers[msg.sender] = 0;
    }

}
