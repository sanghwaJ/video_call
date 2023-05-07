import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import '../const/agora.dart';

class CamScreen extends StatefulWidget {
  const CamScreen({Key? key}) : super(key: key);

  @override
  State<CamScreen> createState() => _CamScreenState();
}

class _CamScreenState extends State<CamScreen> {
  // agora 영상 통화 관련 엔진
  RtcEngine? engine;
  // 내 ID (채널에 접속하면 ID가 갱신됨, 0으로 초기화하는 이유는 채널 접속 전에 나의 아이디가 0임을 알려주기 위함)
  int? uid = 0;
  // 상대방 ID
  int? otherUid;

  // 위젯이 dispose 될 때, 채널 나가기 및 폐기 처리
  @override
  void dispose() async {
    if (engine != null) {
      await engine!.leaveChannel(
        options: LeaveChannelOptions(),
      );
      engine!.release();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('LIVE'),
      ),
      body: FutureBuilder<bool>(
          future: init(),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Center(
                child: Text(
                  snapshot.error.toString(),
                ),
              );
            }

            if (!snapshot.hasData) {
              return Center(
                child: CircularProgressIndicator(),
              );
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  // Stack => 위젯 위에 위젯을 겹치게 구현할 때 사용
                  child: Stack(
                    children: [
                      renderMainView(),
                      Align(
                        alignment: Alignment.topLeft,
                        child: Container(
                          color: Colors.grey,
                          height: 160,
                          width: 120,
                          child: renderSubView(),
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0),
                  child: ElevatedButton(
                    onPressed: () async {
                      if (engine != null) {
                        // 채널 나가기
                        await engine!.leaveChannel();
                        // 엔진을 처음으로 초기화
                        engine = null;
                      }
                      Navigator.of(context).pop();
                    },
                    child: Text(
                      '채널 나가기',
                    ),
                  ),
                ),
              ],
            );
          }),
    );
  }

  // 권한을 가져오는 함수
  Future<bool> init() async {
    // 카메라, 마이크 권한 요청
    final resp = await [Permission.camera, Permission.microphone].request();
    final cameraPermission = resp[Permission.camera];
    final microphonePermission = resp[Permission.microphone];

    if (cameraPermission != PermissionStatus.granted ||
        microphonePermission != PermissionStatus.granted) {
      throw '카메라 또는 마이크 권한이 없습니다.';
    }

    if (engine == null) {
      engine = createAgoraRtcEngine();

      await engine!.initialize(
        RtcEngineContext(
          appId: APP_ID,
        ),
      );

      engine!.registerEventHandler(
        RtcEngineEventHandler(
          // 내가 채널에 입장했을 때
          // connection => 연결 정보 / elapsed => 연결 시간(연결한지 얼마나 됐는지)
          onJoinChannelSuccess: (RtcConnection connection, int elapsed) {
            print('채널에 입장했습니다. uid : ${connection.localUid}');
            setState(() {
              uid = connection.localUid;
            });
          },
          // 내가 채널에서 나갔을 때
          onLeaveChannel: (RtcConnection connection, RtcStats stats) {
            print('채널 퇴장');
            setState(() {
              uid = null;
            });
          },
          // 상대방 유저가 들어왔을 때
          onUserJoined: (RtcConnection connection, int remoteUid, int elapsed) {
            print('상대방이 채널에 입장했습니다. otherUid : ${remoteUid}');
            setState(() {
              otherUid = remoteUid;
            });
          },
          // 상대방 유저가 나갔을 때
          onUserOffline: (RtcConnection connection, int remoteUid,
              UserOfflineReasonType reason) {
            print('상대방이 채널에서 나갔습니다. otherUid : ${remoteUid}');
            setState(() {
              otherUid = null;
            });
          },
        ),
      );

      // 엔진을 실행시키려면 아래의 순서를 지켜야함
      await engine!.enableVideo();
      await engine!.startPreview();
      ChannelMediaOptions options =
          ChannelMediaOptions(); // 여기에 옵션을 추가할 수 있으나, 기본값으로 세팅해도 무방함
      await engine!.joinChannel(
        token: TEMP_TOKEN,
        channelId: CHANNEL_NAME,
        uid: 0,
        options: options,
      );
    }

    return true;
  }

  renderMainView() {
    if (uid == null) {
      return Center(
        child: Text('채널에 참여해주세요.'),
      );
    } else {
      return AgoraVideoView(
        // VideoViewController => 나의 VideoViewController
        controller: VideoViewController(
          rtcEngine: engine!,
          canvas: VideoCanvas(
            uid: 0,
          ),
        ),
      );
    }
  }

  renderSubView() {
    if (otherUid == null) {
      return Center(
        child: Text(
          '채널에 유저가 없습니다.',
        ),
      );
    } else {
      return AgoraVideoView(
        // VideoViewController.remote => 상대방의 VideoViewController
        controller: VideoViewController.remote(
          rtcEngine: engine!,
          canvas: VideoCanvas(uid: otherUid),
          connection: RtcConnection(channelId: CHANNEL_NAME),
        ),
      );
    }
  }
}
