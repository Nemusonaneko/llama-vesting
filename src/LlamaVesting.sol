// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import {ERC20} from "solmate/tokens/ERC20.sol";
import {ERC721} from "solmate/tokens/ERC721.sol";
import {SafeTransferLib} from "solmate/utils/SafeTransferLib.sol";

error NOT_ADMIN();
error NOT_OWNER();
error WITHDRAW_MORE_THAN_AVAILABLE();

contract LlamaVesting is ERC721("Llama Vesting", "LLAMAVEST") {
    using SafeTransferLib for ERC20;

    struct Stream {
        address token;
        uint32 start;
        uint32 end;
        uint32 cliff;
        uint256 amount;
        uint256 claimed;
    }

    uint256 public tokenId;

    mapping(uint256 => Stream) public streams;
    mapping(uint256 => address) public admins;

    function createStream(
        address _token,
        address _to,
        uint256 _amount,
        uint32 _start,
        uint32 _end,
        uint32 _cliff
    ) external {
        uint256 id = tokenId;

        _safeMint(_to, id);

        streams[id] = Stream({
            token: _token,
            start: _start,
            end: _end,
            cliff: _cliff,
            amount: _amount,
            claimed: 0
        });

        admins[id] = msg.sender;

        unchecked {
            tokenId++;
        }

        ERC20(_token).transferFrom(msg.sender, address(this), _amount);
    }

    function claim(
        uint256 _id,
        uint256 _amount,
        address recipient
    ) external {
        if (msg.sender != ownerOf(_id)) revert NOT_ADMIN();
        if (_amount > claimable(_id)) revert WITHDRAW_MORE_THAN_AVAILABLE();
        unchecked {
            streams[_id].claimed += _amount;
        }
        ERC20(streams[_id].token).safeTransfer(recipient, _amount);
    }

    function rug(uint256 _id) external {
        if (admins[_id] != msg.sender) revert NOT_OWNER();
        Stream storage stream = streams[_id];

        uint256 toSendPayee = claimable(_id);
        uint256 toSendPayer;
        unchecked {
            toSendPayer = stream.amount - (stream.claimed + toSendPayee);
            streams[_id].claimed = stream.claimed + toSendPayee;
            streams[_id].end = uint32(block.timestamp);
            streams[_id].amount = streams[_id].claimed;
        }

        ERC20 token = ERC20(stream.token);

        token.safeTransfer(ownerOf(_id), toSendPayee);
        token.safeTransfer(msg.sender, toSendPayer);
    }

    function totalVested(uint256 _id) public view returns (uint256) {
        Stream storage stream = streams[_id];
        if (stream.start + stream.cliff > block.timestamp) {
            return 0;
        } else if (block.timestamp > stream.end) {
            return stream.amount;
        } else {
            return
                stream.amount *
                ((block.timestamp - stream.start) /
                    (stream.end - stream.start));
        }
    }

    function claimable(uint256 _id) public view returns (uint256) {
        return totalVested(_id) - streams[_id].claimed;
    }

    function tokenURI(uint256 id)
        public
        view
        virtual
        override
        returns (string memory)
    {
        return "";
    }
}
