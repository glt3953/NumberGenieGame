//
//  ViewController.m
//  NumberGenieGame
//
//  Created by guoliting on 2017/8/25.
//  Copyright © 2017年 NingXia. All rights reserved.
//

#import "ViewController.h"
#import <Speech/Speech.h>

@interface ViewController () <SFSpeechRecognizerDelegate, AVSpeechSynthesizerDelegate>

@property (nonatomic, strong) UITextView *recognizeTextView;
@property (nonatomic, strong) UIButton *microphoneButton;
@property (nonatomic, strong) SFSpeechRecognizer *speechRecognizer;
@property (nonatomic, strong) SFSpeechAudioBufferRecognitionRequest *recognitionRequest; //处理了语音识别请求，它给语音识别提供了语音输入。
@property (nonatomic, strong) SFSpeechRecognitionTask *recognitionTask; //告诉你语音识别对象的结果，拥有这个对象很方便因为你可以用它删除或者中断任务。
@property (nonatomic, strong) AVAudioEngine *audioEngine; //语音引擎，它负责提供你的语音输入。
@property (nonatomic, copy) NSString *language; //支持的语言，zh-CN:中文，en-US:英文，zh_TW:台湾繁体，zh_HK:香港繁体
@property (nonatomic, copy) NSString *hints; //提示语
@property (nonatomic, strong) AVSpeechSynthesizer *speechSynthesizer; //合成引擎
@property (nonatomic) int randomNumber; //随机数
@property (nonatomic) BOOL isGameOver; //游戏结束
           
@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    
    _hints = @"从0到100中猜个数字，游戏开始。"; //@"This is the UITextView"
    /*
     在info.plist文件里添加了两个键值：
     NSMicrophoneUsageDescription -为获取麦克风语音输入授权的自定义消息。注意这个语音输入授权仅仅只会在用户点击microphone按钮时发生。
     Your microphone will be used to record your speech when you press the 'Start Recording' button.
     NSSpeechRecognitionUsageDescription – 语音识别授权的自定义信息
     Speech recognition will be used to determine which words you speak into this device's microphone.
     */
    CGFloat originX = 10;
    CGFloat originY = 64 + 10;
    CGFloat spaceY = 10;
    CGFloat buttonHeight = 30;
    CGFloat viewWidth = CGRectGetWidth(self.view.bounds) - 2 * originX;
    CGFloat viewHeight = CGRectGetHeight(self.view.bounds) - 2 * originY - buttonHeight - spaceY;
    _recognizeTextView = [[UITextView alloc] initWithFrame:(CGRect){originX, originY, viewWidth, viewHeight}];
    [_recognizeTextView setFont:[UIFont systemFontOfSize:20]];
    [_recognizeTextView setText:_hints];
    [self.view addSubview:_recognizeTextView];
    
    originY += viewHeight + spaceY;
    _microphoneButton = [[UIButton alloc] initWithFrame:(CGRect){originX, originY, viewWidth, buttonHeight}];
    [_microphoneButton.titleLabel setFont:[UIFont systemFontOfSize:20]];
    [_microphoneButton setTitle:@"Start Recording" forState:UIControlStateNormal];
    [_microphoneButton setTitleColor:[UIColor blackColor] forState:UIControlStateNormal];
    [self.view addSubview:_microphoneButton];
    [_microphoneButton addTarget:self action:@selector(microphoneButtonDidClicked:) forControlEvents:UIControlEventTouchUpInside];
    _microphoneButton.enabled = NO;
    _microphoneButton.hidden = YES;
    
    [self startGame];
    
    /* 申请用户语音识别权限
     The app's Info.plist must contain an NSSpeechRecognitionUsageDescription key with a string value explaining to the user how the app uses this data.
     typedef NS_ENUM(NSInteger, SFSpeechRecognizerAuthorizationStatus) {
     //结果未知 用户尚未进行选择
     SFSpeechRecognizerAuthorizationStatusNotDetermined,
     //用户拒绝授权语音识别
     SFSpeechRecognizerAuthorizationStatusDenied,
     //设备不支持语音识别功能
     SFSpeechRecognizerAuthorizationStatusRestricted,
     //用户授权语音识别
     SFSpeechRecognizerAuthorizationStatusAuthorized,
     };*/
    [SFSpeechRecognizer requestAuthorization:^(SFSpeechRecognizerAuthorizationStatus status) {
        BOOL isButtonEnabled = NO;
        switch (status) {
            case SFSpeechRecognizerAuthorizationStatusAuthorized:
            {
                _speechRecognizer = [[SFSpeechRecognizer alloc] initWithLocale:[[NSLocale alloc] initWithLocaleIdentifier:_language]];
                _speechRecognizer.delegate = self;
                
                _audioEngine = [[AVAudioEngine alloc] init];
                
                isButtonEnabled = YES;
            }
                break;
            case SFSpeechRecognizerAuthorizationStatusDenied:
                NSLog(@"User denied access to speech recognition");
                break;
            case SFSpeechRecognizerAuthorizationStatusRestricted:
                NSLog(@"Speech recognition restricted on this device");
                break;
            case SFSpeechRecognizerAuthorizationStatusNotDetermined:
                NSLog(@"Speech recognition not yet authorized");
                break;
            default:
                break;
        }
        
        // 进入主线程执行
        dispatch_async(dispatch_get_main_queue(), ^{
            _microphoneButton.enabled = isButtonEnabled;
        });
    }];
}

- (void)startGame {
    [self speechSynthesizerWithText:_hints];
    _isGameOver = NO;
    _randomNumber = arc4random() % 100;
    //    NSLog(@"随机数：%d", _randomNumber);
}

- (IBAction)microphoneButtonDidClicked:(id)sender {
    if (_audioEngine.isRunning) {
        [_audioEngine stop];
        [_recognitionRequest endAudio];
        _microphoneButton.enabled = NO;
        [_microphoneButton setTitle:@"Start Recording" forState:UIControlStateNormal];
    } else {
        [self startRecording];
        [_microphoneButton setTitle:@"Stop Recording" forState:UIControlStateNormal];
    }
}

- (void)startRecording {
    //检查 recognitionTask 是否在运行，如果运行就取消任务和识别。
    if (_recognitionTask) {
        [_recognitionTask cancel];
        _recognitionTask = nil;
    }
    
    //创建一个 AVAudioSession来为记录语音做准备，在这里我们设置session的类别为recording，模式为measurement，然后激活它。
    AVAudioSession *audioSession = [AVAudioSession sharedInstance];
    NSError *errorSession = nil;
    @try {
        //AVAudioSessionCategoryPlayAndRecord支持录音与播放
        [audioSession setCategory:AVAudioSessionCategoryPlayAndRecord error:&errorSession];
        [audioSession setMode:AVAudioSessionModeMeasurement error:&errorSession];
        [audioSession setActive:YES withOptions:AVAudioSessionSetActiveOptionNotifyOthersOnDeactivation error:&errorSession];
    } @catch (NSException *exception) {
        NSLog(@"audioSession properties weren't set because of an error.");
    }
    
    //实例化recognitionRequest，在这里我们创建了SFSpeechAudioBufferRecognitionRequest对象，利用它把语音数据传到苹果后台。
    _recognitionRequest = [[SFSpeechAudioBufferRecognitionRequest alloc] init];
    if (!_recognitionRequest) {
        NSLog(@"Unable to create an SFSpeechAudioBufferRecognitionRequest object");
    } else {
        //当用户说话的时候让recognitionRequest报告语音识别的部分结果
        _recognitionRequest.shouldReportPartialResults = YES;
    }
    
    //检查 audioEngine（你的设备）是否有录音功能作为语音输入，如果没有，我们就报告一个错误。
    AVAudioInputNode *inputNode = _audioEngine.inputNode;
    if (!inputNode) {
        NSLog(@"Audio engine has no input node");
    }
    
    //调用 speechRecognizer的recognitionTask 方法来开启语音识别。这个方法有一个completion handler回调，这个回调每次都会在识别引擎收到输入并完善当前识别信息时，或者被删除、停止时被调用，最后返回一个最终文本。
    _recognitionTask = [_speechRecognizer recognitionTaskWithRequest:_recognitionRequest resultHandler:^(SFSpeechRecognitionResult * _Nullable result, NSError * _Nullable error) {
        //定义一个布尔值决定识别是否已经结束
        BOOL isFinal = NO;
        
        if (result) {
            //如果结果 result 不是nil, 把 textView.text 的值设置为我们的最优文本。如果结果是最终结果，设置 isFinal为true。
            _recognizeTextView.text = result.bestTranscription.formattedString;
            isFinal = result.isFinal;
            
            if (isFinal) {
                if (_isGameOver) {
                    NSArray *answers = @[@"是", @"好", @"可以"];
                    for (NSUInteger i = 0; i < answers.count; i++) {
                        if ([result.bestTranscription.formattedString containsString:answers[i]]) {
                            [self startGame];
                        }
                    }
                } else {
                    //                [self microphoneButtonDidClicked:nil];
                    int guessNumber = [result.bestTranscription.formattedString intValue];
                    if (guessNumber > 100 || guessNumber < 0) {
                        [self speechSynthesizerWithText:@"不好意思，数字必须在0到100之间，请重猜。"];
                    } else if (guessNumber > _randomNumber) {
                        [self speechSynthesizerWithText:@"猜大了，请重猜。"];
                    } else if (guessNumber < _randomNumber) {
                        [self speechSynthesizerWithText:@"猜小了，请重猜。"];
                    } else {
                        _isGameOver = YES;
                        [self speechSynthesizerWithText:@"恭喜你，答案正确，再玩一次吗？"];
                    }
                }
            }
        }
        
        if (error || isFinal) {
            //如果没有错误或者结果是最终结果，停止 audioEngine(语音输入)并且停止 recognitionRequest 和 recognitionTask.同时，使Start Recording按钮有效。
            [_audioEngine stop];
            [inputNode removeTapOnBus:0];
            _recognitionRequest = nil;
            _recognitionTask = nil;
            _microphoneButton.enabled = YES;
            [_microphoneButton setTitle:@"Start Recording" forState:UIControlStateNormal];
        }
    }];
    
    //向 recognitionRequest增加一个语音输入，注意在开始了recognitionTask之后增加语音输入是OK的，Speech Framework 会在语音输入被加入的同时就开始进行解析识别。
    AVAudioFormat *recordingFormat = [inputNode outputFormatForBus:0];
    [inputNode installTapOnBus:0 bufferSize:1024 format:recordingFormat block:^(AVAudioPCMBuffer * _Nonnull buffer, AVAudioTime * _Nonnull when) {
        [_recognitionRequest appendAudioPCMBuffer:buffer];
    }];
    
    //准备并且开始audioEngine
    [_audioEngine prepare];
    @try {
        NSError *outError = nil;
        [_audioEngine startAndReturnError:&outError];
    } @catch (NSException *exception) {
        NSLog(@"audioEngine couldn't start because of an error.");
    } @finally {
        
    }
    
    if (!_isGameOver) {
        _recognizeTextView.text = [NSString stringWithFormat:@"正确答案是%d，请说出你的答案", _randomNumber];
    }
//    _recognizeTextView.text = @"Say something, I'm listening!";
}

- (void)speechSynthesizerWithText:(NSString *)text {
    /*
     苹果支持的语言如下:
     Arabic (ar-SA)
     Chinese (zh-CN, zh-HK, zh-TW)
     Czech (cs-CZ)
     Danish (da-DK)
     Dutch (nl-BE, nl-NL)
     English (en-AU, en-GB, en-IE, en-US, en-ZA)
     Finnish (fi-FI)
     French (fr-CA, fr-FR)
     German (de-DE)
     Greek (el-GR)
     Hebrew (he-IL)
     Hindi (hi-IN)
     Hungarian (hu-HU)
     Indonesian (id-ID)
     Italian (it-IT)
     Japanese (ja-JP)
     Korean (ko-KR)
     Norwegian (no-NO)
     Polish (pl-PL)
     Portuguese (pt-BR, pt-PT)
     Romanian (ro-RO)
     Russian (ru-RU)
     Slovak (sk-SK)
     Spanish (es-ES, es-MX)
     Swedish (sv-SE)
     Thai (th-TH)
     Turkish (tr-TR)
     */
    if (!_speechSynthesizer) {
        _speechSynthesizer = [[AVSpeechSynthesizer alloc] init];
        _speechSynthesizer.delegate = self;
    }
    _language = @"zh-CN";
    AVSpeechUtterance *utterance = [AVSpeechUtterance speechUtteranceWithString:text];
    AVSpeechSynthesisVoice *voiceType = [AVSpeechSynthesisVoice voiceWithLanguage:_language];
    utterance.voice = voiceType;
    //设置语速
    utterance.rate = AVSpeechUtteranceDefaultSpeechRate;
    //设置音量
    utterance.volume = 1;
    //设置声调,属性值介于0.5(低音调)~2.0(高音调)之间
    utterance.pitchMultiplier = 0.8;
    //本句朗读结束后要延迟多少秒再接着朗读下一秒
    utterance.postUtteranceDelay = 0.1;
    [_speechSynthesizer speakUtterance:utterance];
    _microphoneButton.hidden = YES;
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark - SFSpeechRecognizerDelegate
- (void)speechRecognizer:(SFSpeechRecognizer *)speechRecognizer availabilityDidChange:(BOOL)available {
    _microphoneButton.enabled = available;
}

#pragma mark - AVSpeechSynthesizerDelegate
- (void)speechSynthesizer:(AVSpeechSynthesizer *)synthesizer didStartSpeechUtterance:(AVSpeechUtterance *)utterance {
//    NSLog(@"didStartSpeechUtterance");
}

- (void)speechSynthesizer:(AVSpeechSynthesizer *)synthesizer didFinishSpeechUtterance:(AVSpeechUtterance *)utterance {
//    NSLog(@"didFinishSpeechUtterance");
    [self microphoneButtonDidClicked:nil];
    _microphoneButton.hidden = NO;
}

@end
