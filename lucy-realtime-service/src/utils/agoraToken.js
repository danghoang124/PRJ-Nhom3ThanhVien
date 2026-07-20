const { RtcTokenBuilder, RtcRole } = require('agora-token');

/**
 * Tạo Agora RTC Token cho người dùng vào phòng
 * - uid = 0  → Agora tự cấp UID ngẫu nhiên (ẩn danh)
 * - Role     → SUBSCRIBER (nghe) hoặc PUBLISHER (nói)
 */
function generateAgoraToken(channelName, uid = 0, role = 'PUBLISHER') {
    const appId          = process.env.AGORA_APP_ID;
    const appCertificate = process.env.AGORA_APP_CERTIFICATE;
    const expireTime     = parseInt(process.env.TOKEN_EXPIRY_SECONDS) || 3600;

    if (!appId || appId === 'YOUR_AGORA_APP_ID') {
        // Dev mode: trả về token giả để test giao diện (không cần Agora account)
        return {
            token      : `DEV_TOKEN_${channelName}_${Date.now()}`,
            uid        : uid || Math.floor(Math.random() * 100000),
            channelName,
            expireAt   : new Date(Date.now() + expireTime * 1000).toISOString(),
            isDev      : true,
        };
    }

    const currentTime     = Math.floor(Date.now() / 1000);
    const privilegeExpire = currentTime + expireTime;
    const rtcRole         = role === 'SUBSCRIBER' ? RtcRole.SUBSCRIBER : RtcRole.PUBLISHER;
    const actualUid       = uid || 0; // 0 = Agora tự cấp UID ngẫu nhiên (ẩn danh)

    const token = RtcTokenBuilder.buildTokenWithUid(
        appId, appCertificate, channelName, actualUid, rtcRole, privilegeExpire
    );

    return {
        token,
        uid        : actualUid,
        channelName,
        expireAt   : new Date(privilegeExpire * 1000).toISOString(),
        isDev      : false,
    };
}

module.exports = { generateAgoraToken };
