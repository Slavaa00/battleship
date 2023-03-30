// SPDX-License-Identifier: MIT
pragma solidity =0.8.19;

import {Ownable} from "./Ownable.sol";

error NotPlayer1();
error NotPlayer2();
error WaitForPlayer2();
error Denied();
error PlayersKnown();
error NotTempWinner();
error WrongField();
error OppositePlayerHasTime();

enum GameResult {
    Player1Win,
    Player2Win
}
enum ShotRespond {
    Miss,
    Hit
}
enum State {
    Open,
    Playing,
    CheckingPreviousResult
}

contract Battleship is Ownable {
    event NewTempWinner(address indexed newTempWinner);
    event StateChanged(State indexed newState);
    event GameStarted(
        uint256 indexed startGameTimestamp,
        address indexed player1,
        address indexed player2
    );
    event GameFinished(address indexed newWinner);
    event Player1Joined(address indexed player1, bytes32 indexed player1Commit);
    event Player2Joined(address indexed player2, bytes32 indexed player2Commit);
    event Player1Shot(uint104 indexed player1Shots);
    event Player2Shot(uint104 indexed player2Shots);
    event Player1RespondedHit(
        uint8 indexed player1AliveCells,
        uint104 indexed player1PublicField
    );
    event Player2RespondedHit(
        uint8 indexed player2AliveCells,
        uint104 indexed player2PublicField
    );
    event ContractResetted();

    constructor() {
        _initializeOwner(msg.sender);
    }

    State public state;

    modifier onlyState(State _state) {
        if (state != _state) {
            revert Denied();
        }
        _;
    }

    modifier onlyPlayer() {
        if (whosMove % 2 == 1) {
            if (player1 != msg.sender) {
                revert NotPlayer1();
            }
        } else {
            if (player2 != msg.sender) {
                revert NotPlayer2();
            }
        }
        _;
    }

    modifier onlyTempWinner() {
        if (tempWinner != msg.sender) {
            revert NotTempWinner();
        }
        _;
    }

    uint16 public constant moveTime = 360;

    address public player1;
    address public player2;
    address public tempWinner;
    address public winner;

    uint8 public whosMove = 1;
    uint8 public lastShot = 1;
    uint8 public player1AliveCells = 21;
    uint8 public player2AliveCells = 21;

    uint104 public player1Shots;
    uint104 public player2Shots;

    uint104 public player1PublicField;
    uint104 public player2PublicField;

    uint40 public startGameTimestamp;

    bytes32 public player1Commit;
    bytes32 public player2Commit;

    function joinTheGame(
        bytes32 commit /*uint8[10][10] calldata field,
        string calldata secretPhrase*/
    ) external onlyState(State.Open) returns (bool) {
        if (player1 == address(0)) {
            player1 = msg.sender;
            player1Commit = commit;
            // player1Commit = keccak256(abi.encodePacked(field, secretPhrase));
            emit Player1Joined(msg.sender, commit);

            return true;
        }
        if (player2 == address(0)) {
            if (player1 != msg.sender) {
                player2 = msg.sender;
                player2Commit = commit;
                // player2Commit = keccak256(
                //     abi.encodePacked(field, secretPhrase)
                // );
                emit Player2Joined(msg.sender, commit);

                return true;
            }
        }
        revert PlayersKnown();
    }

    function startGame(
        uint8 target
    ) external onlyState(State.Open) onlyPlayer returns (bool) {
        address _player2 = player2;
        if (_player2 == address(0)) {
            revert WaitForPlayer2();
        }

        state = State.Playing;
        startGameTimestamp = uint40(block.timestamp);

        player1Shots = uint104(1 << (target - 1)) | player1Shots;

        lastShot = target;
        ++whosMove;
        emit StateChanged(State.Playing);
        emit GameStarted(block.timestamp, msg.sender, _player2);

        return true;
    }

    function takeWinForOpponentMoveSkip()
        external
        onlyState(State.Playing)
        returns (address newWinner)
    {
        uint8 _whosMove = whosMove;
        if (
            (block.timestamp - startGameTimestamp) >
            ((_whosMove - 1) * moveTime)
        ) {
            if (_whosMove % 2 == 0) {
                address _player1 = player1;
                winner = _player1;
                _reset();
                emit StateChanged(State.Open);
                emit GameFinished(_player1);

                return _player1;
            } else {
                address _player2 = player2;
                winner = _player2;
                _reset();
                emit StateChanged(State.Open);
                emit GameFinished(_player2);

                return _player2;
            }
        } else {
            revert OppositePlayerHasTime();
        }
    }

    function shoot(
        uint8 target
    ) external onlyState(State.Playing) onlyPlayer returns (uint104) {
        if (player1 == msg.sender) {
            // if (player2AliveCells == 1) {
            //     address _player1 = player1;
            //     state = State.CheckingPreviousResult;
            //     tempWinner = _player1;
            //     emit StateChanged(State.CheckingPreviousResult);
            //     emit NewTempWinner( newTempWinner);

            //     return true;
            // }
            uint104 _player1Shots = player1Shots;
            _player1Shots = uint104(1 << (target - 1)) | _player1Shots;
            player1Shots = _player1Shots;
            lastShot = target;
            ++whosMove;
            emit Player1Shot(_player1Shots);

            return _player1Shots;
        } else {
            // if (player1AliveCells == 1) {
            //     state = State.CheckingPreviousResult;
            //     tempWinner = player2;
            //     emit StateChanged(State.CheckingPreviousResult);
            //     emit NewTempWinner( newTempWinner);

            //     return true;
            // }

            uint104 _player2Shots = player2Shots;
            _player2Shots = uint104(1 << (target - 1)) | _player2Shots;
            player2Shots = _player2Shots;
            lastShot = target;
            ++whosMove;
            emit Player2Shot(_player2Shots);

            return _player2Shots;
        }
    }

    function respondHit()
        external
        onlyState(State.Playing)
        onlyPlayer
        returns (uint8, address newTempWinner)
    {
        if (player1 == msg.sender) {
            uint8 _player1AliveCells = player1AliveCells;
            player1AliveCells = --_player1AliveCells;

            if (_player1AliveCells == 1) {
                address _player2 = player2;
                state = State.CheckingPreviousResult;
                tempWinner = _player2;
                emit StateChanged(State.CheckingPreviousResult);
                emit NewTempWinner(_player2);

                return (0, _player2);
            }
            uint104 _player1PublicField = player1PublicField;
            _player1PublicField =
                uint104(1 << (lastShot - 1)) |
                _player1PublicField;
            player1PublicField = _player1PublicField;
            ++whosMove;
            emit Player1RespondedHit(_player1AliveCells, _player1PublicField);
            return (_player1AliveCells, address(0));
        } else {
            uint8 _player2AliveCells = player2AliveCells;
            player2AliveCells = --_player2AliveCells;

            if (_player2AliveCells == 1) {
                address _player1 = player1;
                state = State.CheckingPreviousResult;
                tempWinner = player1;
                emit StateChanged(State.CheckingPreviousResult);
                emit NewTempWinner(_player1);

                return (0, _player1);
            }
            uint104 _player2PublicField = player2PublicField;

            _player2PublicField =
                uint104(1 << (lastShot - 1)) |
                _player2PublicField;
            player2PublicField = _player2PublicField;
            ++whosMove;
            emit Player2RespondedHit(_player2AliveCells, _player2PublicField);
            return (_player2AliveCells, address(0));
        }
    }

    function commitCheck(
        uint8[10][10] calldata field,
        string calldata secretPhrase
    )
        external
        onlyState(State.CheckingPreviousResult)
        onlyTempWinner
        returns (GameResult)
    {
        if (checkFieldForRules(field)) {
            if (player1 == msg.sender) {
                address _player2 = player2;
                bytes32 commit = keccak256(
                    abi.encodePacked(field, secretPhrase)
                );
                if (compareCommitFromState(commit, msg.sender, _player2)) {
                    return GameResult.Player2Win;
                }
                // if (commit != player1Commit) {
                //     winner = _player2;
                //     _reset();
                //     emit StateChanged(State.Open);

                //     emit GameFinished(_player2);

                //     return (GameResult.Player2Win, _player2);
                // }
                uint104 commitField;
                unchecked {
                    for (uint256 i; i < 10; ++i) {
                        for (uint256 j; j < 10; ++j) {
                            uint104 tempTick;
                            if (field[i][j] != 0) {
                                tempTick = uint104(1 << (j + (i * 10)));
                                commitField = commitField | tempTick;
                            }
                        }
                    }
                }
                if ((player2Shots & commitField) != player1PublicField) {
                    winner = _player2;
                    _reset();
                    emit StateChanged(State.Open);

                    emit GameFinished(_player2);

                    return (GameResult.Player2Win);
                }
                winner = msg.sender;
                _reset();
                emit StateChanged(State.Open);

                emit GameFinished(msg.sender);

                return (GameResult.Player1Win);
            } else {
                address _player1 = player1;

                bytes32 commit = keccak256(
                    abi.encodePacked(field, secretPhrase)
                );
                if (compareCommitFromState(commit, _player1, msg.sender)) {
                    return GameResult.Player1Win;
                }

                // if (commit != player2Commit) {
                //     winner = player1;
                //     _reset();
                //     emit StateChanged(State.Open);

                //     emit GameFinished(_player1);

                //     return (GameResult.Player1Win, _player1);
                // }
                uint104 commitField;
                unchecked {
                    for (uint256 i; i < 10; ++i) {
                        for (uint256 j; j < 10; ++j) {
                            uint104 tempTick;
                            if (field[i][j] != 0) {
                                tempTick = uint104(1 << (j + (i * 10)));
                                commitField = commitField | tempTick;
                            }
                        }
                    }
                }
                if ((player1Shots & commitField) != player2PublicField) {
                    winner = player1;
                    _reset();
                    emit StateChanged(State.Open);

                    emit GameFinished(_player1);

                    return (GameResult.Player1Win);
                }
                winner = msg.sender;
                _reset();
                emit StateChanged(State.Open);

                emit GameFinished(msg.sender);

                return (GameResult.Player2Win);
            }
        } else {
            revert WrongField();
        }
    }

    function compareCommitFromState(
        bytes32 commit,
        address _player1,
        address _player2
    ) private returns (bool ok) {
        if (_player1 == msg.sender) {
            if (commit != player1Commit) {
                winner = _player2;
                _reset();
                emit StateChanged(State.Open);

                emit GameFinished(_player2);

                return ok = true;
            }
        } else {
            if (commit != player2Commit) {
                winner = _player1;
                _reset();
                emit StateChanged(State.Open);

                emit GameFinished(_player1);

                return ok = true;
            }
        }
    }

    function checkFieldForRules(
        uint8[10][10] calldata _field
    ) public pure returns (bool ok) {
        uint256 one;
        uint256 twentyOne;
        uint256 twentyTwo;
        uint256 twentyThree;
        uint256 thirtyOne;
        uint256 thirtyTwo;
        uint256 four;

        unchecked {
            for (uint256 i; i < 10; ++i) {
                for (uint256 j; j < 10; ++j) {
                    uint256 cell = _field[i][j];
                    if (cell != 0) {
                        if (cell == 1) {
                            ++one;

                            if (checkOneCell(i, j, 99, _field)) {
                                continue;
                            }
                            return ok;
                        }

                        if (cell == 21) {
                            ++twentyOne;

                            if (checkOneCell(i, j, 21, _field)) {
                                continue;
                            }
                            return ok;
                        }
                        if (cell == 22) {
                            ++twentyTwo;

                            if (checkOneCell(i, j, 22, _field)) {
                                continue;
                            }
                            return ok;
                        }
                        if (cell == 23) {
                            ++twentyThree;

                            if (checkOneCell(i, j, 23, _field)) {
                                continue;
                            }
                            return ok;
                        }
                        if (cell == 31) {
                            ++thirtyOne;

                            if (checkOneCell(i, j, 31, _field)) {
                                continue;
                            }
                            return ok;
                        }
                        if (cell == 32) {
                            ++thirtyTwo;

                            if (checkOneCell(i, j, 32, _field)) {
                                continue;
                            }
                            return ok;
                        }

                        if (cell == 4) {
                            ++four;
                            if (checkOneCell(i, j, 4, _field)) {
                                continue;
                            }
                            return ok;
                        }
                    } else {
                        continue;
                    }
                }
            }
        }

        if (one == 4) {
            if (twentyOne == 2) {
                if (twentyTwo == 2) {
                    if (twentyThree == 2) {
                        if (thirtyOne == 3) {
                            if (thirtyTwo == 3) {
                                if (four == 4) {
                                    return ok = true;
                                } else {
                                    return ok;
                                }
                            } else {
                                return ok;
                            }
                        } else {
                            return ok;
                        }
                    } else {
                        return ok;
                    }
                } else {
                    return ok;
                }
            } else {
                return ok;
            }
        } else {
            return ok;
        }
    }

    function checkOneCell(
        uint256 i,
        uint256 j,
        uint256 omit,
        uint8[10][10] calldata field_
    ) private pure returns (bool ok) {
        if (omit != 99) {
            if (j == 0 || j == 9) {
                if (j == 0) {
                    if (field_[i + 1][j + 1] == omit) {
                        return ok;
                    }
                }
                if (j == 9) {
                    if (field_[i + 1][j - 1] == omit) {
                        return ok;
                    }
                }
            }
            if (i != 9 && j != 0 && j != 9) {
                if (
                    field_[i + 1][j - 1] == omit || field_[i + 1][j + 1] == omit
                ) {
                    return ok;
                }
            }
        }
        if (i == 0 || i == 9 || j == 0 || j == 9) {
            if (i == 0) {
                if (j == 0) {
                    if (field_[i][j + 1] != 0 && field_[i][j + 1] != omit) {
                        return ok;
                    }
                    if (field_[i + 1][j] != 0 && field_[i + 1][j] != omit) {
                        return ok;
                    }
                    if (
                        field_[i + 1][j + 1] != 0 &&
                        field_[i + 1][j + 1] != omit
                    ) {
                        return ok;
                    }
                    return ok = true;
                }
                if (j == 9) {
                    if (field_[i][j - 1] != 0 && field_[i][j - 1] != omit) {
                        return ok;
                    }
                    if (
                        field_[i + 1][j - 1] != 0 &&
                        field_[i + 1][j - 1] != omit
                    ) {
                        return ok;
                    }
                    if (field_[i + 1][j] != 0 && field_[i + 1][j] != omit) {
                        return ok;
                    }
                    return ok = true;
                }

                if (field_[i + 1][j] != 0 && field_[i + 1][j] != omit) {
                    return ok;
                }
                if (field_[i][j + 1] != 0 && field_[i][j + 1] != omit) {
                    return ok;
                }
                if (field_[i][j - 1] != 0 && field_[i][j - 1] != omit) {
                    return ok;
                }
                if (field_[i + 1][j + 1] != 0 && field_[i][j + 1] != omit) {
                    return ok;
                }
                if (field_[i + 1][j - 1] != 0 && field_[i][j - 1] != omit) {
                    return ok;
                }
                return ok = true;
            }
            if (i == 9) {
                if (j == 0) {
                    if (field_[i - 1][j] != 0 && field_[i - 1][j] != omit) {
                        return ok;
                    }
                    if (
                        field_[i - 1][j + 1] != 0 &&
                        field_[i - 1][j + 1] != omit
                    ) {
                        return ok;
                    }
                    if (field_[i][j + 1] != 0 && field_[i][j + 1] != omit) {
                        return ok;
                    }
                    return ok = true;
                }
                if (j == 9) {
                    if (field_[i - 1][j] != 0 && field_[i - 1][j] != omit) {
                        return ok;
                    }
                    if (
                        field_[i - 1][j - 1] != 0 &&
                        field_[i - 1][j - 1] != omit
                    ) {
                        return ok;
                    }
                    if (field_[i][j - 1] != 0 && field_[i][j - 1] != omit) {
                        return ok;
                    }
                    return ok = true;
                }
                if (field_[i - 1][j] != 0 && field_[i - 1][j] != omit) {
                    return ok;
                }
                if (field_[i][j + 1] != 0 && field_[i][j + 1] != omit) {
                    return ok;
                }
                if (field_[i][j - 1] != 0 && field_[i][j - 1] != omit) {
                    return ok;
                }
                if (field_[i - 1][j + 1] != 0 && field_[i - 1][j + 1] != omit) {
                    return ok;
                }
                if (field_[i - 1][j - 1] != 0 && field_[i - 1][j - 1] != omit) {
                    return ok;
                }
                return ok = true;
            }

            if (j == 0 || j == 9) {
                if (j == 0) {
                    if (field_[i - 1][j] != 0 && field_[i - 1][j] != omit) {
                        return ok;
                    }
                    if (
                        field_[i - 1][j + 1] != 0 &&
                        field_[i - 1][j + 1] != omit
                    ) {
                        return ok;
                    }
                    if (field_[i][j + 1] != 0 && field_[i][j + 1] != omit) {
                        return ok;
                    }
                    if (
                        field_[i + 1][j + 1] != 0 &&
                        field_[i + 1][j + 1] != omit
                    ) {
                        return ok;
                    }
                    if (field_[i + 1][j] != 0 && field_[i + 1][j] != omit) {
                        return ok;
                    }
                    return ok = true;
                }

                if (j == 9) {
                    if (field_[i - 1][j] != 0 && field_[i - 1][j] != omit) {
                        return ok;
                    }
                    if (
                        field_[i - 1][j - 1] != 0 &&
                        field_[i - 1][j - 1] != omit
                    ) {
                        return ok;
                    }
                    if (field_[i][j - 1] != 0 && field_[i][j - 1] != omit) {
                        return ok;
                    }
                    if (
                        field_[i + 1][j - 1] != 0 &&
                        field_[i + 1][j - 1] != omit
                    ) {
                        return ok;
                    }
                    if (field_[i + 1][j] != 0 && field_[i + 1][j] != omit) {
                        return ok;
                    }
                    return ok = true;
                }
            }
        } else {
            if (field_[i - 1][j - 1] != 0 && field_[i - 1][j - 1] != omit) {
                return ok;
            }
            if (field_[i - 1][j] != 0 && field_[i - 1][j] != omit) {
                return ok;
            }
            if (field_[i - 1][j + 1] != 0 && field_[i - 1][j + 1] != omit) {
                return ok;
            }
            if (field_[i][j + 1] != 0 && field_[i][j + 1] != omit) {
                return ok;
            }
            if (field_[i + 1][j + 1] != 0 && field_[i + 1][j + 1] != omit) {
                return ok;
            }
            if (field_[i + 1][j] != 0 && field_[i + 1][j] != omit) {
                return ok;
            }
            if (field_[i + 1][j - 1] != 0 && field_[i + 1][j - 1] != omit) {
                return ok;
            }
            if (field_[i][j - 1] != 0 && field_[i][j - 1] != omit) {
                return ok;
            }
            return ok = true;
        }
    }

    function _reset() internal {
        state = State.Open;
        delete player1;
        delete player2;
        delete player1Commit;
        delete player2Commit;
        delete player1Shots;
        delete player2Shots;
        delete player1PublicField;
        delete player2PublicField;
        delete startGameTimestamp;
        player1AliveCells = 21;
        player2AliveCells = 21;
        whosMove = 1;

        emit ContractResetted();
    }

    function reset() external onlyOwner returns (bool) {
        _reset();
        return true;
    }
}
