// Nội dung trang Hướng dẫn sử dụng (bản GMO). Đây là nguồn duy nhất của hướng dẫn: sửa tại đây,
// bản Word/PDF gửi khách được xuất lại từ file này. Định dạng trong chuỗi: **đậm**, *nghiêng*, `mã`.
import conversationFlow from 'assets/images/user-guide/conversation-flow.png';

export default {
  intro:
    'GMO Connect gom tin nhắn từ mọi kênh (Zalo OA, Facebook, website, email) về một màn hình chung để đội ngũ cùng trả lời khách hàng. Tài liệu này mô tả luồng làm việc cơ bản, không đi vào từng tính năng nhỏ.',
  sections: [
    {
      id: 'overview',
      title: 'Tổng quan',
      blocks: [
        {
          type: 'p',
          text: 'Mỗi tin nhắn khách gửi đến đều trở thành một **hội thoại** trong hộp thư chung. Nhân viên (hoặc trợ lý AI) trả lời ngay trên GMO Connect, câu trả lời được gửi ngược về đúng kênh khách đang dùng.',
        },
        {
          type: 'table',
          head: ['Khái niệm', 'Ý nghĩa'],
          rows: [
            [
              'Kênh',
              'Nơi khách nhắn tin: Zalo OA, Facebook, email, khung chat trên website',
            ],
            [
              'Hộp thư',
              'Một kênh đã kết nối vào hệ thống. Mỗi hộp thư có danh sách nhân viên được phép xử lý',
            ],
            [
              'Hội thoại',
              'Toàn bộ trao đổi với một khách trên một hộp thư. Trạng thái: Mở, Chờ giải quyết, Tạm dừng, Đã được giải quyết',
            ],
            [
              'Liên hệ',
              'Hồ sơ khách hàng: tên, số điện thoại, email, lịch sử hội thoại',
            ],
            [
              'Nhân viên / Nhóm',
              'Người xử lý hội thoại; nhóm gom nhân viên theo bộ phận (CSKH, Kinh doanh…)',
            ],
            ['Nhãn', 'Thẻ phân loại hội thoại, ví dụ “khiếu nại”, “báo giá”'],
            [
              'GMO AI',
              'Trợ lý AI tự trả lời khách dựa trên tài liệu và câu hỏi thường gặp của doanh nghiệp; chuyển cho nhân viên khi cần người thật',
            ],
          ],
        },
        {
          type: 'p',
          text: 'Thanh menu bên trái có các mục chính: **Trang Chủ**, **Hội thoại**, **Liên hệ**, **Báo cáo**, mục trợ lý AI và **Cài Đặt**. Những gì bạn thấy phụ thuộc vào vai trò của bạn.',
        },
      ],
    },
    {
      id: 'roles',
      title: 'Vai trò người dùng',
      blocks: [
        {
          type: 'p',
          text: 'Có ba vai trò. Nhân viên chỉ thấy hội thoại trong các hộp thư mình được thêm vào; Giám sát viên và Quản trị viên thấy tất cả.',
        },
        {
          type: 'table',
          head: [
            'Vai trò',
            'Hội thoại',
            'Báo cáo',
            'Quản lý nhân viên, nhóm',
            'Cài đặt hệ thống',
          ],
          rows: [
            [
              'Quản trị viên',
              'Mọi hộp thư, được xóa',
              'Có',
              'Thêm, sửa, xóa',
              'Có',
            ],
            [
              'Giám sát viên',
              'Mọi hộp thư, phân công lại',
              'Có',
              'Xem nhân viên, sắp xếp thành viên nhóm',
              'Không',
            ],
            ['Nhân viên', 'Hộp thư được giao', 'Không', 'Không', 'Không'],
          ],
        },
        {
          type: 'p',
          text: 'Vai trò do Quản trị viên chọn khi mời nhân viên và có thể đổi sau trong **Cài Đặt → Nhân viên**.',
        },
      ],
    },
    {
      id: 'login',
      title: 'Đăng nhập',
      blocks: [
        {
          type: 'p',
          text: 'Mỗi người dùng một tài khoản riêng, đăng nhập bằng email công việc. Không dùng chung tài khoản, vì hệ thống ghi lại ai đã trả lời và xử lý hội thoại nào.',
        },
        {
          type: 'ol',
          items: [
            '**Kích hoạt tài khoản** — khi được Quản trị viên mời, bạn nhận một email. Bấm đường dẫn trong email và đặt mật khẩu cho lần đầu.',
            '**Đăng nhập** — mở địa chỉ [địa chỉ truy cập hệ thống] trên trình duyệt (nên dùng Chrome hoặc Edge trên máy tính), nhập email, mật khẩu rồi bấm *Đăng nhập*.',
            '**Quên mật khẩu** — ở trang đăng nhập bấm *Quên mật khẩu?*, nhập email, rồi mở email vừa nhận để đặt mật khẩu mới.',
            '**Không vào được** — chưa nhận được email mời, hoặc đăng nhập báo sai email: liên hệ Quản trị viên của doanh nghiệp để kiểm tra và gửi lại lời mời.',
          ],
        },
        {
          type: 'p',
          text: 'Sau khi đăng nhập, bấm **Hội thoại** trên menu trái để bắt đầu làm việc.',
        },
      ],
    },
    {
      id: 'setup',
      title: 'Thiết lập ban đầu (Quản trị viên)',
      blocks: [
        {
          type: 'p',
          text: 'Làm một lần khi bắt đầu dùng, theo thứ tự dưới đây. Tất cả nằm trong mục **Cài Đặt**.',
        },
        {
          type: 'ol',
          items: [
            '**Mời nhân viên** — Cài Đặt → Nhân viên → thêm tên, email và vai trò. Nhân viên nhận email để đặt mật khẩu.',
            '**Kết nối kênh** — Cài Đặt → Hộp thư → thêm hộp thư, chọn loại kênh và làm theo hướng dẫn kết nối (đăng nhập trang Facebook, cấp quyền cho Zalo OA, dán mã nhúng khung chat vào website…). Cuối bước này chọn nhân viên được xử lý hộp thư.',
            '**Tạo nhóm** — Cài Đặt → Nhóm, gom nhân viên theo bộ phận để chuyển hội thoại cho cả nhóm thay vì từng người.',
            '**Chọn cách phân công** — trong cài đặt hộp thư, bật tự động phân công để hội thoại mới được chia lần lượt cho nhân viên đang trực tuyến; tắt đi nếu muốn nhân viên tự nhận.',
            '**(Tuỳ chọn) Bật trợ lý AI** — nạp tài liệu, câu hỏi thường gặp rồi gắn trợ lý vào hộp thư (xem phần cuối).',
            '**(Tuỳ chọn) Tạo nhãn và thư mẫu phản hồi** — để nhân viên phân loại và trả lời nhanh các câu hay gặp.',
          ],
        },
        {
          type: 'p',
          text: 'Sau bước 2, tin nhắn mới từ kênh đó sẽ bắt đầu hiện trong mục **Hội thoại**.',
        },
      ],
    },
    {
      id: 'flow',
      title: 'Luồng xử lý một hội thoại',
      blocks: [
        {
          type: 'p',
          text: 'Mỗi hội thoại đi từ lúc khách nhắn đến cho tới khi được giải quyết, có hoặc không qua trợ lý AI.',
        },
        {
          type: 'image',
          src: conversationFlow,
          alt: 'Trợ lý AI trả lời trước, nhân viên nhận khi cần người thật',
        },
        {
          type: 'p',
          text: 'Nếu hộp thư không gắn trợ lý AI, hội thoại đi thẳng tới bước phân công. Hội thoại do AI đang xử lý nằm ở tab *Đang xử lý*, nhân viên có thể mở ra và nhận thay bất cứ lúc nào.',
        },
      ],
    },
    {
      id: 'daily',
      title: 'Công việc hằng ngày theo vai trò',
      blocks: [
        {
          type: 'p',
          text: 'Mỗi vai trò có một nhịp làm việc riêng: nhân viên xử lý hội thoại, giám sát viên điều phối và theo dõi chất lượng, quản trị viên giữ cho hệ thống chạy ổn định.',
        },
        { type: 'h3', text: 'Nhân viên' },
        {
          type: 'p',
          text: 'Một ngày làm việc xoay quanh mục **Hội thoại**: nhận việc, trả lời, rồi đóng lại khi xong.',
        },
        {
          type: 'ol',
          items: [
            '**Đăng nhập và bật trạng thái Trực tuyến** (ảnh đại diện góc dưới bên trái). Chỉ nhân viên trực tuyến mới được tự động phân công.',
            {
              text: '**Xem việc cần làm** — vào Hội thoại, ba tab trên cùng:',
              items: [
                '*Mở*: hội thoại khách mới nhắn, chưa ai nhận — mở ra và bấm tự nhận.',
                '*Đang xử lý*: hội thoại đã có người nhận, đang được AI trả lời hoặc đang tạm dừng chờ khách. Muốn xem riêng hội thoại của mình, bấm nút *Lọc* và chọn người phụ trách là bạn.',
                '*Đã xử lý*: hội thoại đã được giải quyết.',
              ],
            },
            '**Trả lời khách** — gõ vào ô *Trả lời* ở cuối hội thoại. Gõ `/` để chèn thư mẫu phản hồi, đính kèm tệp nếu cần.',
            '**Trao đổi nội bộ** — chuyển sang tab *Lưu ý riêng*. Ghi chú này khách không thấy; gõ `@tên` để gọi đồng nghiệp vào hỗ trợ.',
            '**Phân loại và chuyển giao** — ở cột bên phải, gắn nhãn, hoặc đổi người phụ trách / nhóm nếu việc thuộc bộ phận khác.',
            '**Kết thúc** — bấm *Giải quyết* khi xong. Nếu đang chờ khách gửi thêm thông tin, chọn *Tạm dừng* đến một thời điểm; hội thoại tự mở lại khi đến hạn hoặc khi khách nhắn tiếp.',
          ],
        },
        {
          type: 'p',
          text: 'Khi khách nhắn lại vào một hội thoại đã giải quyết, hội thoại tự mở lại và quay về tab *Đang xử lý* (hoặc tab *Mở* nếu chưa có người phụ trách).',
        },
        { type: 'h3', text: 'Giám sát viên' },
        {
          type: 'p',
          text: 'Giám sát viên thấy mọi hộp thư. Việc chính là không để hội thoại nào bị bỏ sót và chia đều khối lượng cho đội.',
        },
        {
          type: 'ol',
          items: [
            '**Đầu ca: nắm tình hình** — mở **Giám sát nhóm** để xem ai đang trực tuyến và mỗi người đang giữ bao nhiêu hội thoại.',
            '**Dọn hội thoại tồn** — trong Hội thoại, xem tab *Mở* và mục *Không giám sát* (hội thoại khách đang chờ phản hồi), rồi phân công ngay cho người phù hợp.',
            '**Điều phối trong ca** — phân công lại khi một nhân viên quá tải, nghỉ đột xuất hoặc hội thoại cần bộ phận khác; sắp xếp lại thành viên nhóm khi cần.',
            '**Hỗ trợ ca khó** — mở hội thoại, đọc lịch sử và để lại *Lưu ý riêng* (gõ `@tên`) để hướng dẫn nhân viên; khi cần có thể trả lời khách trực tiếp.',
            '**Cuối ngày, cuối tuần: xem Báo cáo** — thời gian phản hồi, số hội thoại đã giải quyết theo nhân viên và nhóm, mức hài lòng của khách; trao đổi với nhân viên có chỉ số thấp.',
          ],
        },
        { type: 'h3', text: 'Quản trị viên' },
        {
          type: 'p',
          text: 'Quản trị viên làm được mọi việc của giám sát viên, cộng thêm phần cài đặt. Phần lớn việc của quản trị viên phát sinh khi có thay đổi, không phải mỗi ngày.',
        },
        {
          type: 'ol',
          items: [
            '**Quản lý nhân sự** — khi có người vào hoặc nghỉ: mời hoặc xóa nhân viên, đổi vai trò, cập nhật nhóm và hộp thư được giao (Cài Đặt → Nhân viên, Nhóm, Hộp thư).',
            '**Kiểm tra kết nối kênh** — khi khách báo đã nhắn mà không thấy tin, vào Cài Đặt → Hộp thư kiểm tra kênh đó và kết nối lại nếu bị ngắt (ví dụ trang Facebook đổi người quản trị).',
            '**Cập nhật kiến thức cho GMO AI** — khi có sản phẩm, giá hay chính sách mới: bổ sung *Tài liệu*, *Câu hỏi thường gặp*, rồi thử lại trong *Khu thử nghiệm*.',
            '**Duy trì công cụ làm việc** — thêm nhãn, thư mẫu phản hồi và quy tắc tự động hoá khi đội gặp câu hỏi lặp lại hoặc cần cách phân loại mới.',
            '**Theo dõi như giám sát viên** — xem Giám sát nhóm và Báo cáo. Chỉ quản trị viên mới xóa được hội thoại và nhập hoặc xóa liên hệ hàng loạt.',
          ],
        },
      ],
    },
    {
      id: 'tools',
      title: 'Liên hệ, trợ lý AI và Báo cáo',
      blocks: [
        {
          type: 'p',
          text: 'Ba mục này hỗ trợ cho việc xử lý hội thoại, không phải nơi làm việc chính.',
        },
        {
          type: 'p',
          text: '**Liên hệ** — mỗi khách nhắn đến được tự tạo một liên hệ. Mở liên hệ để xem mọi hội thoại cũ của khách trên mọi kênh, bổ sung số điện thoại, email, ghi chú. Nếu doanh nghiệp dùng Perfex CRM, thông tin khách được đồng bộ sang đó.',
        },
        {
          type: 'p',
          text: '**Trợ lý AI** (menu *GMO AI*) — trả lời khách thay nhân viên dựa trên kiến thức doanh nghiệp cung cấp. Quản trị viên thiết lập theo thứ tự:',
        },
        {
          type: 'ol',
          items: [
            'Nạp kiến thức vào *Tài liệu* và *Câu hỏi thường gặp*.',
            'Thử hỏi đáp trong *Khu thử nghiệm* cho đến khi câu trả lời đạt yêu cầu.',
            'Gắn trợ lý vào hộp thư ở mục *Hộp thư* của trợ lý.',
          ],
        },
        {
          type: 'p',
          text: 'Khi không trả lời được hoặc khách muốn gặp người thật, trợ lý chuyển hội thoại cho nhân viên (xem sơ đồ luồng xử lý).',
        },
        {
          type: 'p',
          text: '**Báo cáo** (Quản trị viên, Giám sát viên) — *Tổng quan* cho biết số hội thoại, thời gian phản hồi và thời gian giải quyết; các báo cáo con chia theo nhân viên, hộp thư, nhóm, nhãn và mức hài lòng của khách. Nên xem hằng tuần để phát hiện hộp thư bị trả lời chậm.',
        },
      ],
    },
    {
      id: 'feedback',
      title: 'Góp ý và báo lỗi',
      blocks: [
        {
          type: 'p',
          text: 'Trong thời gian dùng thử, mọi góp ý và lỗi gặp phải đều được ghi nhận để hoàn thiện hệ thống. Gửi cho đầu mối hỗ trợ: [họ tên, số điện thoại / Zalo, email].',
        },
        {
          type: 'ol',
          items: [
            '**Lỗi chặn công việc** (không nhận được tin của khách, không gửi được trả lời, không đăng nhập được): gọi hoặc nhắn Zalo trực tiếp cho đầu mối hỗ trợ ngay khi gặp.',
            '**Lỗi khác và góp ý** (sai số liệu, giao diện khó dùng, đề xuất tính năng): gửi qua [kênh tiếp nhận góp ý], có thể gom lại gửi một lần trong ngày.',
          ],
        },
        {
          type: 'p',
          text: 'Khi báo lỗi, ghi kèm các thông tin sau để đội kỹ thuật tìm ra nhanh:',
        },
        {
          type: 'ol',
          items: [
            'Tài khoản đang dùng và vai trò (Quản trị viên, Giám sát viên, Nhân viên).',
            'Thời điểm xảy ra và kênh liên quan (Zalo OA, Facebook, email, khung chat website).',
            'Mã hội thoại: con số ở cuối địa chỉ trên trình duyệt khi đang mở hội thoại (ví dụ …/conversations/125 thì mã là 125).',
            'Các bước đã làm, kết quả thấy được và kết quả mong muốn.',
            'Ảnh chụp màn hình hoặc video ngắn.',
          ],
        },
        {
          type: 'p',
          text: 'Đội hỗ trợ phản hồi trong vòng [thời hạn phản hồi] kể từ khi nhận được báo lỗi.',
        },
      ],
    },
  ],
};
