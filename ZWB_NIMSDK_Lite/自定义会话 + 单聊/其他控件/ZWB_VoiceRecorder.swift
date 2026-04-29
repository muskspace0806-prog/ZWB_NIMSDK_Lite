//
//  ZWB_VoiceRecorder.swift
//  ZWB_NIMSDK_Lite
//
//  语音录制管理器
//  封装 AVAudioRecorder，提供开始/停止/取消接口
//  录制完成后回调文件路径和时长（秒）
//

import AVFoundation

/// 语音录制结果
struct ZWB_VoiceResult {
    /// 录音文件本地路径
    let filePath: String
    /// 录音时长（秒）
    let duration: Int
}

class ZWB_VoiceRecorder: NSObject {

    // MARK: - 回调

    /// 录制完成回调（取消时不触发）
    var onFinished: ((ZWB_VoiceResult) -> Void)?
    /// 录制失败回调
    var onFailed: ((String) -> Void)?
    /// 实时音量回调（0.0 ~ 1.0），用于显示录音动画
    var onVolumeChanged: ((Float) -> Void)?

    // MARK: - 常量

    /// 最短录音时长（秒），低于此时长不发送
    private let minDuration: TimeInterval = 1.0
    /// 最长录音时长（秒）
    private let maxDuration: TimeInterval = 60.0

    // MARK: - 内部状态

    private var recorder: AVAudioRecorder?
    private var startTime: Date?
    private var volumeTimer: Timer?
    private var maxTimer: Timer?
    private var isCancelled = false

    // MARK: - 开始录音

    /// 请求麦克风权限并开始录音
    func startRecording() {
        AVAudioSession.sharedInstance().requestRecordPermission { [weak self] granted in
            DispatchQueue.main.async {
                if granted {
                    self?.doStartRecording()
                } else {
                    self?.onFailed?("请在设置中开启麦克风权限")
                }
            }
        }
    }

    private func doStartRecording() {
        isCancelled = false

        // 配置音频会话
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playAndRecord, mode: .default, options: .defaultToSpeaker)
        try? session.setActive(true)

        // 录音文件路径
        let fileName = "voice_\(Int(Date().timeIntervalSince1970)).aac"
        let filePath = (NSTemporaryDirectory() as NSString).appendingPathComponent(fileName)
        let url = URL(fileURLWithPath: filePath)

        // 录音参数
        let settings: [String: Any] = [
            AVFormatIDKey:            kAudioFormatMPEG4AAC,
            AVSampleRateKey:          16000,
            AVNumberOfChannelsKey:    1,
            AVEncoderAudioQualityKey: AVAudioQuality.medium.rawValue
        ]

        guard let rec = try? AVAudioRecorder(url: url, settings: settings) else {
            onFailed?("录音初始化失败")
            return
        }

        rec.isMeteringEnabled = true
        rec.record()
        recorder  = rec
        startTime = Date()

        // 实时音量更新
        volumeTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            self?.recorder?.updateMeters()
            let power = self?.recorder?.averagePower(forChannel: 0) ?? -60
            // 将 dB（-60 ~ 0）映射到 0 ~ 1
            let volume = max(0, (power + 60) / 60)
            self?.onVolumeChanged?(volume)
        }

        // 超时自动停止
        maxTimer = Timer.scheduledTimer(withTimeInterval: maxDuration, repeats: false) { [weak self] _ in
            self?.stopRecording()
        }
    }

    // MARK: - 停止录音（发送）

    func stopRecording() {
        guard let rec = recorder, rec.isRecording else { return }
        let duration = Int(Date().timeIntervalSince(startTime ?? Date()))
        let filePath = rec.url.path

        rec.stop()
        cleanup()

        guard !isCancelled else { return }

        if duration < Int(minDuration) {
            onFailed?("录音时间太短")
            try? FileManager.default.removeItem(atPath: filePath)
            return
        }

        onFinished?(ZWB_VoiceResult(filePath: filePath, duration: duration))
    }

    // MARK: - 取消录音

    func cancelRecording() {
        isCancelled = true
        let filePath = recorder?.url.path
        recorder?.stop()
        cleanup()
        if let path = filePath {
            try? FileManager.default.removeItem(atPath: path)
        }
    }

    // MARK: - 清理

    private func cleanup() {
        volumeTimer?.invalidate(); volumeTimer = nil
        maxTimer?.invalidate();    maxTimer    = nil
        recorder  = nil
        startTime = nil
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    /// 是否正在录音
    var isRecording: Bool { recorder?.isRecording ?? false }
}
