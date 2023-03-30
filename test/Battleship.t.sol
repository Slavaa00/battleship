// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {BaseTest, console} from "./utils/BaseTest.sol";
import "../src/Battleship.sol";

contract BattleshipTest is BaseTest {
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

    address player1;
    address player2;
    address player3;
    Battleship battleship;

    uint8[21] player1FutureShots = [
        1,
        2,
        10,
        21,
        22,
        29,
        30,
        41,
        42,
        43,
        48,
        49,
        50,
        61,
        62,
        77,
        78,
        79,
        80,
        91,
        100
    ];
    uint8[21] player2FutureShots = [
        1,
        2,
        10,
        21,
        22,
        29,
        30,
        41,
        42,
        43,
        48,
        49,
        50,
        61,
        62,
        77,
        78,
        79,
        80,
        91,
        100
    ];

    // It will be done on UI
    uint8[10][10] field1 = [
        [1, 0, 0, 0, 0, 0, 0, 0, 0, 1],
        [0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
        [21, 21, 0, 0, 0, 0, 0, 0, 22, 22],
        [0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
        [31, 31, 31, 0, 0, 0, 0, 32, 32, 32],
        [0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
        [23, 23, 0, 0, 0, 0, 0, 0, 0, 0],
        [0, 0, 0, 0, 0, 0, 4, 4, 4, 4],
        [0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
        [1, 0, 0, 0, 0, 0, 0, 0, 0, 1]
    ];
    string secretPhrase1 = "qwe";

    bytes32 player1Commit = keccak256(abi.encodePacked(field1, secretPhrase1));

    uint8[10][10] field2 = [
        [0, 1, 0, 0, 0, 0, 0, 0, 0, 1],
        [0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
        [21, 21, 0, 0, 0, 0, 0, 0, 22, 22],
        [0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
        [31, 31, 31, 0, 0, 0, 0, 32, 32, 32],
        [0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
        [23, 23, 0, 0, 0, 0, 0, 0, 0, 0],
        [0, 0, 0, 0, 0, 0, 4, 4, 4, 4],
        [0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
        [1, 0, 0, 0, 0, 0, 0, 0, 0, 1]
    ];
    string secretPhrase2 = "rty";
    bytes32 player2Commit = keccak256(abi.encodePacked(field2, secretPhrase2));

    constructor() {
        string[] memory labels = new string[](3);
        labels[0] = "player1";
        labels[1] = "player2";
        labels[2] = "player3";

        preSetup(3, labels);
    }

    function setUp() public override {
        super.setUp();
        player1 = users[0];
        player2 = users[1];
        player3 = users[2];

        battleship = new Battleship();
        assertEq(battleship.owner(), address(this));
    }

    function test_joinAndWinTheGameForPlayer1() public {
        vm.expectEmit(true, true, true, true);
        emit Player1Joined(address(this), player1Commit);
        battleship.joinTheGame(player1Commit);

        assertEq(battleship.checkFieldForRules(field1), true);
        assertEq(battleship.checkFieldForRules(field2), true);

        vm.expectRevert(PlayersKnown.selector);
        battleship.joinTheGame(player1Commit);

        vm.expectRevert(WaitForPlayer2.selector);
        battleship.startGame(1);

        vm.expectRevert(Denied.selector);
        battleship.takeWinForOpponentMoveSkip();

        vm.expectRevert(Denied.selector);
        battleship.shoot(1);

        vm.expectRevert(Denied.selector);
        battleship.respondHit();

        vm.expectRevert(Denied.selector);
        battleship.commitCheck(field1, secretPhrase1);

        vm.startPrank(player2);

        vm.expectEmit(true, true, true, true);
        emit Player2Joined(player2, player2Commit);
        battleship.joinTheGame(player2Commit);

        vm.expectRevert(NotPlayer1.selector);
        battleship.startGame(1);

        vm.stopPrank();

        vm.startPrank(player3);
        vm.expectRevert(PlayersKnown.selector);
        battleship.joinTheGame(player2Commit);
        vm.stopPrank();

        assertEq(uint256(battleship.state()), 0);
        assertEq(battleship.player1(), address(this));
        assertEq(battleship.player2(), (player2));
        assertEq(battleship.tempWinner(), address(0));
        assertEq((battleship.moveTime()), 360);
        assertEq((battleship.whosMove()), 1);
        assertEq((battleship.lastShot()), 1);
        assertEq((battleship.player1AliveCells()), 21);
        assertEq((battleship.player2AliveCells()), 21);
        assertEq((battleship.player1Shots()), 0);
        assertEq((battleship.player2Shots()), 0);
        assertEq((battleship.player1PublicField()), 0);
        assertEq((battleship.player2PublicField()), 0);
        assertEq((battleship.startGameTimestamp()), 0);
        assertEq((battleship.player1Commit()), player1Commit);
        assertEq((battleship.player2Commit()), player2Commit);

        vm.expectEmit(true, true, true, true);
        emit StateChanged(State.Playing);
        emit GameStarted(block.timestamp, address(this), player2);
        battleship.startGame(player1FutureShots[0]);

        assertEq(uint256(battleship.state()), 1);
        assertEq(battleship.startGameTimestamp(), block.timestamp);
        assertEq(battleship.player1Shots(), 1);
        assertEq(battleship.lastShot(), 1);
        assertEq(battleship.whosMove(), 2);

        vm.expectRevert(NotPlayer2.selector);
        battleship.shoot(player1FutureShots[1]);

        vm.expectRevert(OppositePlayerHasTime.selector);
        battleship.takeWinForOpponentMoveSkip();

        vm.startPrank(player2);

        vm.expectEmit(true, true, true, true);
        emit Player2Shot(1);
        battleship.shoot(player2FutureShots[0]);

        vm.stopPrank();

        vm.expectEmit(true, true, true, true);
        emit Player1RespondedHit(20, 1);
        battleship.respondHit();

        assertEq(uint256(battleship.state()), 1);
        assertEq(battleship.player2Shots(), 1);
        assertEq(battleship.player1AliveCells(), 20);
        assertEq(battleship.player1PublicField(), 1);
        assertEq(battleship.lastShot(), 1);
        assertEq(battleship.whosMove(), 4);

        vm.startPrank(player2);
        vm.expectEmit(true, true, true, true);
        emit Player2Shot(3);
        battleship.shoot(player2FutureShots[1]);
        vm.stopPrank();

        for (uint256 i = 1; i < 20; ++i) {
            battleship.shoot(player1FutureShots[i]);

            vm.startPrank(player2);
            battleship.respondHit();
            vm.stopPrank();
        }
        // Last Shot and Respond
        battleship.shoot(player1FutureShots[20]);

        vm.startPrank(player2);

        vm.expectEmit(true, true, true, true);
        emit StateChanged(State.CheckingPreviousResult);
        emit NewTempWinner(address(this));
        battleship.respondHit();

        vm.stopPrank();

        assertEq(uint256(battleship.state()), 2);
        assertEq(battleship.player1AliveCells(), 20);
        assertEq(battleship.player2AliveCells(), 1);
        assertEq(battleship.player1Shots(), 635064373524815727111730889219);
        assertEq(battleship.player2Shots(), 3);
        assertEq(battleship.player1PublicField(), 1);
        assertEq(battleship.player2PublicField(), 1239073410701026363379286530);
        assertEq(battleship.lastShot(), 100);
        assertEq(battleship.whosMove(), 44);

        assertEq(battleship.tempWinner(), address(this));
        assertEq(battleship.winner(), address(0));

        vm.startPrank(player2);
        vm.expectRevert(NotTempWinner.selector);
        battleship.commitCheck(field2, secretPhrase2);
        vm.stopPrank();

        vm.expectEmit(true, true, true, true);
        emit StateChanged(State.Open);
        emit GameFinished(address(this));
        battleship.commitCheck(field1, secretPhrase1);

        assertEq(battleship.winner(), address(this));

        assertEq(uint256(battleship.state()), 0);
        assertEq(battleship.player1(), address(0));
        assertEq(battleship.player2(), address(0));
        assertEq(battleship.player1Commit(), 0);
        assertEq(battleship.player2Commit(), 0);
        assertEq(battleship.player1Shots(), 0);
        assertEq(battleship.player2Shots(), 0);
        assertEq(battleship.player1PublicField(), 0);
        assertEq(battleship.player2PublicField(), 0);
        assertEq(battleship.startGameTimestamp(), 0);
        assertEq(battleship.player1AliveCells(), 21);
        assertEq(battleship.player2AliveCells(), 21);
        assertEq(battleship.whosMove(), 1);
    }

    function test_Player2WinsByHits() public {
        battleship.joinTheGame(player1Commit);

        vm.startPrank(player2);
        battleship.joinTheGame(player2Commit);
        vm.stopPrank();

        battleship.startGame(player1FutureShots[0]);

        vm.startPrank(player2);
        battleship.shoot(player2FutureShots[0]);

        vm.stopPrank();

        battleship.respondHit();

        for (uint256 i = 2; i < 20; ++i) {
            vm.startPrank(player2);
            battleship.shoot(player2FutureShots[i]);
            vm.stopPrank();

            battleship.respondHit();
        }
        vm.startPrank(player2);
        battleship.shoot(player2FutureShots[20]);

        vm.stopPrank();

        vm.expectEmit(true, true, true, true);
        emit StateChanged(State.CheckingPreviousResult);
        emit NewTempWinner(player2);
        battleship.respondHit();

        vm.expectEmit(true, true, true, true);
        emit StateChanged(State.Open);
        emit GameFinished(player2);
        vm.startPrank(player2);
        battleship.commitCheck(field2, secretPhrase2);
        vm.stopPrank();

        assertEq(battleship.winner(), player2);
    }

    function test_Player1WinsBecausePlayer2CheatedWithRespondHit() public {
        battleship.joinTheGame(player1Commit);

        vm.startPrank(player2);
        battleship.joinTheGame(player2Commit);
        vm.stopPrank();

        battleship.startGame(player1FutureShots[1]);

        vm.startPrank(player2);
        battleship.shoot(player2FutureShots[0]);

        vm.stopPrank();

        battleship.respondHit();

        for (uint256 i = 2; i < 20; ++i) {
            vm.startPrank(player2);
            battleship.shoot(player2FutureShots[i]);
            vm.stopPrank();

            battleship.respondHit();
        }
        vm.startPrank(player2);
        battleship.shoot(player2FutureShots[20]);

        vm.stopPrank();

        battleship.respondHit();

        vm.expectEmit(true, true, true, true);
        emit StateChanged(State.Open);
        emit GameFinished(address(this));
        vm.startPrank(player2);
        battleship.commitCheck(field2, secretPhrase2);
        vm.stopPrank();

        assertEq(battleship.winner(), address(this));
    }

    function test_Player1WinsBecausePlayer2ProvideFakeField() public {
        uint8[10][10] memory fakeField2 = [
            [0, 0, 0, 1, 0, 0, 0, 0, 0, 1],
            [0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
            [21, 21, 0, 0, 0, 0, 0, 0, 22, 22],
            [0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
            [31, 31, 31, 0, 0, 0, 0, 32, 32, 32],
            [0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
            [23, 23, 0, 0, 0, 0, 0, 0, 0, 0],
            [0, 0, 0, 0, 0, 0, 4, 4, 4, 4],
            [0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
            [1, 0, 0, 0, 0, 0, 0, 0, 0, 1]
        ];

        battleship.joinTheGame(player1Commit);

        vm.startPrank(player2);
        battleship.joinTheGame(player2Commit);
        vm.stopPrank();

        battleship.startGame(player1FutureShots[0]);

        vm.startPrank(player2);
        battleship.shoot(player2FutureShots[0]);

        vm.stopPrank();

        battleship.respondHit();

        for (uint256 i = 2; i < 20; ++i) {
            vm.startPrank(player2);
            battleship.shoot(player2FutureShots[i]);
            vm.stopPrank();

            battleship.respondHit();
        }
        vm.startPrank(player2);
        battleship.shoot(player2FutureShots[20]);

        vm.stopPrank();

        battleship.respondHit();

        vm.startPrank(player2);
        battleship.commitCheck(fakeField2, secretPhrase2);
        vm.stopPrank();

        assertEq(battleship.winner(), address(this));
    }

    function test_Player1WinsBecausePlayer2ProvideFakePhrase() public {
        string memory fakeSecretPhrase2 = "456";

        uint8[10][10] memory illegalField2 = [
            [1, 1, 1, 1, 1, 1, 1, 1, 1, 1],
            [0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
            [21, 21, 0, 0, 0, 0, 0, 0, 22, 22],
            [0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
            [31, 31, 31, 0, 0, 0, 0, 32, 32, 32],
            [0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
            [23, 23, 0, 0, 0, 0, 0, 0, 0, 0],
            [0, 0, 0, 0, 0, 0, 4, 4, 4, 4],
            [0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
            [1, 0, 0, 0, 0, 0, 0, 0, 0, 1]
        ];

        battleship.joinTheGame(player1Commit);

        vm.startPrank(player2);
        battleship.joinTheGame(player2Commit);
        vm.stopPrank();

        battleship.startGame(player1FutureShots[0]);

        vm.startPrank(player2);
        battleship.shoot(player2FutureShots[0]);

        vm.stopPrank();

        battleship.respondHit();

        for (uint256 i = 2; i < 20; ++i) {
            vm.startPrank(player2);
            battleship.shoot(player2FutureShots[i]);
            vm.stopPrank();

            battleship.respondHit();
        }
        vm.startPrank(player2);
        battleship.shoot(player2FutureShots[20]);

        vm.stopPrank();

        battleship.respondHit();

        vm.startPrank(player2);
        vm.expectRevert(WrongField.selector);
        battleship.commitCheck(illegalField2, secretPhrase2);

        battleship.commitCheck(field2, fakeSecretPhrase2);
        vm.stopPrank();

        assertEq(battleship.winner(), address(this));
    }

    function test_Player2WinsBecausePlayer1ProvideFakeField() public {
        uint8[10][10] memory fakeField1 = [
            [0, 0, 0, 0, 0, 0, 0, 1, 0, 1],
            [0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
            [21, 21, 0, 0, 0, 0, 0, 0, 22, 22],
            [0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
            [31, 31, 31, 0, 0, 0, 0, 32, 32, 32],
            [0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
            [23, 23, 0, 0, 0, 0, 0, 0, 0, 0],
            [0, 0, 0, 0, 0, 0, 4, 4, 4, 4],
            [0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
            [1, 0, 0, 0, 0, 0, 0, 0, 0, 1]
        ];

        battleship.joinTheGame(player1Commit);

        vm.startPrank(player2);
        battleship.joinTheGame(player2Commit);
        vm.stopPrank();

        battleship.startGame(player1FutureShots[0]);

        vm.startPrank(player2);
        battleship.shoot(player2FutureShots[0]);

        vm.stopPrank();

        battleship.respondHit();

        vm.startPrank(player2);
        battleship.shoot(player2FutureShots[1]);
        vm.stopPrank();

        for (uint256 i = 1; i < 21; ++i) {
            battleship.shoot(player1FutureShots[i]);

            vm.startPrank(player2);
            battleship.respondHit();
            vm.stopPrank();
        }

        vm.expectEmit(true, true, true, true);
        emit StateChanged(State.Open);
        emit GameFinished(player2);
        battleship.commitCheck(fakeField1, secretPhrase1);

        assertEq(battleship.winner(), player2);
    }

    function test_Player2WinsBecausePlayer1ProvideFakePhrase() public {
        string memory fakeSecretPhrase1 = "123";

        battleship.joinTheGame(player1Commit);

        vm.startPrank(player2);
        battleship.joinTheGame(player2Commit);
        vm.stopPrank();

        battleship.startGame(player1FutureShots[0]);

        vm.startPrank(player2);
        battleship.shoot(player2FutureShots[0]);

        vm.stopPrank();

        battleship.respondHit();

        vm.startPrank(player2);
        battleship.shoot(player2FutureShots[1]);
        vm.stopPrank();
        //assertEq(whosMove,5 );

        for (uint256 i = 1; i < 21; ++i) {
            battleship.shoot(player1FutureShots[i]);

            vm.startPrank(player2);
            battleship.respondHit();
            vm.stopPrank();
        }

        vm.expectEmit(true, true, true, true);
        emit StateChanged(State.Open);
        emit GameFinished(player2);
        battleship.commitCheck(field1, fakeSecretPhrase1);

        assertEq(battleship.winner(), player2);
    }

    function test_Player2WinsBecausePlayer1CheatedWithRespondHit() public {
        battleship.joinTheGame(player1Commit);

        vm.startPrank(player2);
        battleship.joinTheGame(player2Commit);
        vm.stopPrank();

        battleship.startGame(player1FutureShots[0]);

        vm.startPrank(player2);
        battleship.shoot(player2FutureShots[0]);

        vm.stopPrank();

        //assertEq(whosMove,5 );

        for (uint256 i = 1; i < 21; ++i) {
            battleship.shoot(player1FutureShots[i]);

            vm.startPrank(player2);
            battleship.respondHit();
            vm.stopPrank();
        }
        assertEq(battleship.tempWinner(), address(this));
        assertEq(battleship.winner(), address(0));

        // console.log(battleship.commitCheck(field1, secretPhrase1));
        vm.expectEmit(true, true, true, true);
        emit StateChanged(State.Open);
        emit GameFinished(player2);
        assertEq(uint256(battleship.commitCheck(field1, secretPhrase1)), (1));

        assertEq(battleship.winner(), player2);
    }

    function test_Player2WinsBecausePlayer1SkippedMove() public {
        battleship.joinTheGame(player1Commit);

        vm.startPrank(player2);
        battleship.joinTheGame(player2Commit);
        vm.stopPrank();

        battleship.startGame(player1FutureShots[0]);

        vm.startPrank(player2);
        battleship.shoot(player2FutureShots[0]);
        vm.stopPrank();

        vm.warp(
            battleship.startGameTimestamp() + (battleship.moveTime() * 2) + 1
        );

        vm.startPrank(player2);

        vm.expectEmit(true, true, true, true);
        emit StateChanged(State.Open);
        emit GameFinished(player2);
        battleship.takeWinForOpponentMoveSkip();

        vm.stopPrank();

        assertEq(battleship.winner(), player2);
    }

    function test_Player1WinsBecausePlayer2SkippedMove() public {
        battleship.joinTheGame(player1Commit);

        vm.startPrank(player2);
        battleship.joinTheGame(player2Commit);
        vm.stopPrank();

        battleship.startGame(player1FutureShots[0]);

        vm.warp(battleship.startGameTimestamp() + (battleship.moveTime()) + 1);

        vm.expectEmit(true, true, true, true);
        emit StateChanged(State.Open);
        emit GameFinished(player2);
        battleship.takeWinForOpponentMoveSkip();

        assertEq(battleship.winner(), address(this));
    }

    // Tradeoff between possibility to win against owner and possible Denial Of Service provided by one of the player by not checking his commit after winning the game (even when playing against the owner if it would be restricted to reset the contract for owner if he's playing himself).
    function test_OwnerCanAlwaysResetContract() public {
        assertEq(battleship.owner(), address(this));

        battleship.joinTheGame(player1Commit);

        vm.startPrank(player2);
        battleship.joinTheGame(player2Commit);
        vm.stopPrank();

        battleship.startGame(player1FutureShots[0]);

        vm.startPrank(player2);
        battleship.shoot(player2FutureShots[0]);

        vm.stopPrank();

        battleship.respondHit();

        vm.startPrank(player2);
        battleship.shoot(player2FutureShots[1]);
        vm.stopPrank();

        for (uint256 i = 1; i < 21; ++i) {
            battleship.shoot(player1FutureShots[i]);

            vm.startPrank(player2);
            battleship.respondHit();
            vm.stopPrank();
        }
        assertEq(battleship.tempWinner(), address(this));

        vm.expectEmit(true, true, true, true);
        emit ContractResetted();
        battleship.reset();

        assertEq(uint256(battleship.state()), 0);
        assertEq(battleship.player1(), address(0));
        assertEq(battleship.player2(), address(0));
        assertEq(battleship.player1Commit(), 0);
        assertEq(battleship.player2Commit(), 0);
        assertEq(battleship.player1Shots(), 0);
        assertEq(battleship.player2Shots(), 0);
        assertEq(battleship.player1PublicField(), 0);
        assertEq(battleship.player2PublicField(), 0);
        assertEq(battleship.startGameTimestamp(), 0);
        assertEq(battleship.player1AliveCells(), 21);
        assertEq(battleship.player2AliveCells(), 21);
        assertEq(battleship.whosMove(), 1);
    }

    function test_checkFieldForRules() public {
        uint8[10][10] memory _fieldGood = [
            [1, 0, 0, 0, 0, 0, 0, 0, 0, 1],
            [0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
            [21, 21, 0, 0, 0, 0, 0, 0, 22, 22],
            [0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
            [31, 31, 31, 0, 0, 0, 0, 32, 32, 32],
            [0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
            [23, 23, 0, 0, 0, 0, 0, 0, 0, 0],
            [0, 0, 0, 0, 0, 0, 4, 4, 4, 4],
            [0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
            [1, 0, 0, 0, 0, 0, 0, 0, 0, 1]
        ];
        uint8[10][10] memory _fieldGood10Row = [
            [1, 0, 0, 0, 0, 0, 0, 0, 0, 1],
            [0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
            [21, 21, 0, 0, 0, 0, 0, 0, 22, 22],
            [0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
            [31, 31, 31, 0, 0, 0, 0, 32, 32, 32],
            [0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
            [23, 23, 0, 0, 0, 0, 0, 0, 0, 0],
            [0, 0, 0, 0, 0, 0, 4, 4, 4, 4],
            [0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
            [0, 0, 0, 0, 1, 0, 0, 0, 0, 1]
        ];
        uint8[10][10] memory _fieldWithout1 = [
            [0, 0, 0, 0, 0, 0, 0, 0, 0, 1],
            [0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
            [21, 21, 0, 0, 0, 0, 0, 0, 22, 22],
            [0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
            [31, 31, 31, 0, 0, 0, 0, 32, 32, 32],
            [0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
            [23, 23, 0, 0, 0, 0, 0, 0, 0, 0],
            [0, 0, 0, 0, 0, 0, 4, 4, 4, 4],
            [0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
            [1, 0, 0, 0, 0, 0, 0, 0, 0, 1]
        ];
        uint8[10][10] memory _fieldWithout21 = [
            [1, 0, 0, 0, 0, 0, 0, 0, 0, 1],
            [0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
            [21, 0, 0, 0, 0, 0, 0, 0, 22, 22],
            [0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
            [31, 31, 31, 0, 0, 0, 0, 32, 32, 32],
            [0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
            [23, 23, 0, 0, 0, 0, 0, 0, 0, 0],
            [0, 0, 0, 0, 0, 0, 4, 4, 4, 4],
            [0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
            [1, 0, 0, 0, 0, 0, 0, 0, 0, 1]
        ];
        uint8[10][10] memory _fieldWithout22 = [
            [1, 0, 0, 0, 0, 0, 0, 0, 0, 1],
            [0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
            [21, 21, 0, 0, 0, 0, 0, 0, 0, 22],
            [0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
            [31, 31, 31, 0, 0, 0, 0, 32, 32, 32],
            [0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
            [23, 23, 0, 0, 0, 0, 0, 0, 0, 0],
            [0, 0, 0, 0, 0, 0, 4, 4, 4, 4],
            [0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
            [1, 0, 0, 0, 0, 0, 0, 0, 0, 1]
        ];
        uint8[10][10] memory _fieldWithout23 = [
            [1, 0, 0, 0, 0, 0, 0, 0, 0, 1],
            [0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
            [21, 21, 0, 0, 0, 0, 0, 0, 22, 22],
            [0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
            [31, 31, 31, 0, 0, 0, 0, 32, 32, 32],
            [0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
            [23, 0, 0, 0, 0, 0, 0, 0, 0, 0],
            [0, 0, 0, 0, 0, 0, 4, 4, 4, 4],
            [0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
            [1, 0, 0, 0, 0, 0, 0, 0, 0, 1]
        ];
        uint8[10][10] memory _fieldWithout31 = [
            [1, 0, 0, 0, 0, 0, 0, 0, 0, 1],
            [0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
            [21, 21, 0, 0, 0, 0, 0, 0, 22, 22],
            [0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
            [31, 31, 0, 0, 0, 0, 0, 32, 32, 32],
            [0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
            [23, 23, 0, 0, 0, 0, 0, 0, 0, 0],
            [0, 0, 0, 0, 0, 0, 4, 4, 4, 4],
            [0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
            [1, 0, 0, 0, 0, 0, 0, 0, 0, 1]
        ];
        uint8[10][10] memory _fieldWithout32 = [
            [1, 0, 0, 0, 0, 0, 0, 0, 0, 1],
            [0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
            [21, 21, 0, 0, 0, 0, 0, 0, 22, 22],
            [0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
            [31, 31, 31, 0, 0, 0, 0, 0, 32, 32],
            [0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
            [23, 23, 0, 0, 0, 0, 0, 0, 0, 0],
            [0, 0, 0, 0, 0, 0, 4, 4, 4, 4],
            [0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
            [1, 0, 0, 0, 0, 0, 0, 0, 0, 1]
        ];
        uint8[10][10] memory _fieldWithout4 = [
            [1, 0, 0, 0, 0, 0, 0, 0, 0, 1],
            [0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
            [21, 21, 0, 0, 0, 0, 0, 0, 22, 22],
            [0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
            [31, 31, 31, 0, 0, 0, 0, 32, 32, 32],
            [0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
            [23, 23, 0, 0, 0, 0, 0, 0, 0, 0],
            [0, 0, 0, 0, 0, 0, 0, 4, 4, 4],
            [0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
            [1, 0, 0, 0, 0, 0, 0, 0, 0, 1]
        ];
        uint8[10][10] memory _fieldTwo1sClose = [
            [1, 1, 0, 0, 0, 0, 0, 0, 0, 0],
            [0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
            [21, 21, 0, 0, 0, 0, 0, 0, 22, 22],
            [0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
            [31, 31, 31, 0, 0, 0, 0, 32, 32, 32],
            [0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
            [23, 23, 0, 0, 0, 0, 0, 0, 0, 0],
            [0, 0, 0, 0, 0, 0, 4, 4, 4, 4],
            [0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
            [1, 0, 0, 0, 0, 0, 0, 0, 0, 1]
        ];
        uint8[10][10] memory _fieldDiagonal21 = [
            [1, 0, 0, 0, 0, 0, 0, 0, 0, 1],
            [0, 0, 21, 0, 0, 0, 0, 0, 0, 0],
            [0, 21, 0, 0, 0, 0, 0, 0, 22, 22],
            [0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
            [31, 31, 31, 0, 0, 0, 0, 32, 32, 32],
            [0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
            [23, 23, 0, 0, 0, 0, 0, 0, 0, 0],
            [0, 0, 0, 0, 0, 0, 4, 4, 4, 4],
            [0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
            [1, 0, 0, 0, 0, 0, 0, 0, 0, 1]
        ];
        uint8[10][10] memory _fieldDiagonal22 = [
            [1, 0, 0, 0, 0, 0, 0, 0, 0, 1],
            [0, 0, 0, 0, 0, 0, 0, 22, 0, 0],
            [21, 21, 0, 0, 0, 0, 0, 0, 22, 0],
            [0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
            [31, 31, 31, 0, 0, 0, 0, 32, 32, 32],
            [0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
            [23, 23, 0, 0, 0, 0, 0, 0, 0, 0],
            [0, 0, 0, 0, 0, 0, 4, 4, 4, 4],
            [0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
            [1, 0, 0, 0, 0, 0, 0, 0, 0, 1]
        ];
        uint8[10][10] memory _fieldDiagonal23 = [
            [1, 0, 0, 0, 0, 0, 0, 0, 0, 1],
            [0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
            [21, 21, 0, 0, 0, 0, 0, 0, 22, 22],
            [0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
            [31, 31, 31, 0, 0, 0, 0, 32, 32, 32],
            [0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
            [0, 23, 0, 0, 0, 0, 0, 0, 0, 0],
            [0, 0, 23, 0, 0, 0, 4, 4, 4, 4],
            [0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
            [1, 0, 0, 0, 0, 0, 0, 0, 0, 1]
        ];

        assertEq(battleship.checkFieldForRules(_fieldGood), true);
        assertEq(battleship.checkFieldForRules(_fieldGood10Row), true);
        assertEq(battleship.checkFieldForRules(_fieldWithout1), false);
        assertEq(battleship.checkFieldForRules(_fieldWithout21), false);
        assertEq(battleship.checkFieldForRules(_fieldWithout22), false);
        assertEq(battleship.checkFieldForRules(_fieldWithout23), false);
        assertEq(battleship.checkFieldForRules(_fieldWithout31), false);
        assertEq(battleship.checkFieldForRules(_fieldWithout32), false);
        assertEq(battleship.checkFieldForRules(_fieldWithout4), false);
        assertEq(battleship.checkFieldForRules(_fieldTwo1sClose), false);
        assertEq(battleship.checkFieldForRules(_fieldDiagonal21), false);
        assertEq(battleship.checkFieldForRules(_fieldDiagonal22), false);
        assertEq(battleship.checkFieldForRules(_fieldDiagonal23), false);
    }

    function test_checkFieldForRules2() public {
        uint8[10][10] memory _fieldDiagonal31 = [
            [1, 0, 0, 0, 0, 0, 0, 0, 0, 1],
            [0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
            [21, 21, 0, 0, 31, 0, 0, 0, 22, 22],
            [0, 0, 0, 31, 0, 0, 0, 0, 0, 0],
            [0, 0, 31, 0, 0, 0, 0, 32, 32, 32],
            [0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
            [23, 23, 0, 0, 0, 0, 0, 0, 0, 0],
            [0, 0, 0, 0, 0, 0, 4, 4, 4, 4],
            [0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
            [1, 0, 0, 0, 0, 0, 0, 0, 0, 1]
        ];
        uint8[10][10] memory _fieldDiagonal32 = [
            [1, 0, 0, 0, 0, 0, 0, 0, 0, 1],
            [0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
            [21, 21, 0, 0, 0, 0, 0, 0, 22, 22],
            [0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
            [31, 31, 31, 0, 0, 0, 32, 0, 0, 0],
            [0, 0, 0, 0, 0, 32, 0, 0, 0, 0],
            [23, 23, 0, 0, 32, 0, 0, 0, 0, 0],
            [0, 0, 0, 0, 0, 0, 4, 4, 4, 4],
            [0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
            [1, 0, 0, 0, 0, 0, 0, 0, 0, 1]
        ];
        uint8[10][10] memory _fieldDiagonal4 = [
            [1, 0, 0, 0, 0, 0, 0, 0, 0, 1],
            [0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
            [21, 21, 0, 0, 0, 0, 0, 0, 22, 22],
            [0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
            [31, 31, 31, 0, 0, 0, 0, 32, 32, 32],
            [0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
            [23, 23, 0, 0, 0, 0, 0, 0, 0, 4],
            [0, 0, 0, 0, 0, 0, 0, 0, 4, 0],
            [0, 0, 0, 0, 0, 0, 0, 4, 0, 0],
            [1, 0, 0, 0, 0, 0, 4, 0, 0, 1]
        ];

        assertEq(battleship.checkFieldForRules(_fieldDiagonal31), false);
        assertEq(battleship.checkFieldForRules(_fieldDiagonal32), false);
        assertEq(battleship.checkFieldForRules(_fieldDiagonal4), false);
    }
}
