# Kết nối Văn Học Mở với Supabase

Ứng dụng dùng Supabase Auth để đăng nhập và PostgreSQL để lưu hồ sơ, tiến độ, điểm số và hoạt động. Mật khẩu không được lưu trong bảng ứng dụng. Row Level Security (RLS) giới hạn học sinh chỉ đọc/ghi dữ liệu của mình; giáo viên được đọc tiến độ của học sinh.

## 1. Tạo project và schema

1. Tạo project tại [supabase.com](https://supabase.com/).
2. Mở **SQL Editor → New query**.
3. Sao chép toàn bộ `cloud-schema.sql`, chạy bằng **Run**.
4. Mở query mới, chạy toàn bộ `literary-works-seed.sql` để nạp sáu tác phẩm ban đầu.

Nội dung tác phẩm, phần đọc, giới thiệu, thẻ chủ đề và câu hỏi trắc nghiệm được tải từ bảng `literary_works`. Tài khoản đã đăng nhập có quyền đọc; chỉ quản trị viên Supabase chỉnh nội dung trong Table Editor hoặc SQL Editor. File seed dùng `ON CONFLICT DO NOTHING`, nên chạy lại không ghi đè nội dung tác phẩm đã sửa.

## 2. Đăng ký học sinh và duyệt giáo viên

Người học có thể tạo tài khoản ngay ở tab **Tạo tài khoản** trên website. Schema tự tạo hồ sơ với vai trò `student`. Người đăng ký đánh dấu mình là giáo viên sẽ tạo thêm yêu cầu chờ duyệt; metadata đăng ký không thể tự cấp quyền giáo viên.

1. Sau khi schema đã được chạy, học sinh điền họ tên, lớp, email và mật khẩu trên website. Nếu Supabase yêu cầu xác nhận email, người dùng cần bấm liên kết trong email trước khi đăng nhập.
2. Giáo viên cũng đăng ký trên website và đánh dấu ô yêu cầu quyền giáo viên. Để xem các yêu cầu, quản trị viên chạy:

```sql
select r.user_id, p.email, p.name, p.class_name, r.created_at
from public.teacher_access_requests r
join public.profiles p on p.id = r.user_id
where r.status = 'pending'
order by r.created_at;
```

3. Sau khi xác minh giáo viên, quản trị viên cấp quyền bằng email chính xác:

```sql
update public.profiles
set role = 'teacher'
where email = 'giaovien@example.com';

update public.teacher_access_requests r
set status = 'approved', reviewed_at = now()
from public.profiles p
where r.user_id = p.id and p.email = 'giaovien@example.com';
```

Nếu từ chối, thay `approved` bằng `rejected` trong câu lệnh cập nhật request. Chỉ quản trị viên Supabase mới nên chạy các lệnh duyệt này. Không bật quyền giáo viên dựa trên mã bí mật đặt trong frontend.

Các tài khoản và tiến độ cũ trong `localStorage` không được tự động chuyển sang database cloud.

Nếu website báo không cho đăng ký, vào **Authentication → Providers → Email** và bật **Allow new users to sign up**. Có thể giữ xác nhận email bật để Supabase xác minh địa chỉ email trước lần đăng nhập đầu tiên. [Tài liệu cấu hình Supabase Auth](https://supabase.com/docs/guides/auth/general-configuration).

## 3. Cấu hình trình duyệt

1. Trong Supabase Dashboard, lấy **Project URL** và **Publishable key** của project.
2. Điền chúng vào `supabase-config.js`.
3. Đưa các thay đổi lên GitHub để redeploy trang.

Publishable key sẽ nằm trong JavaScript gửi đến trình duyệt. Đây là dự kiến; quyền truy cập được giới hạn bằng RLS. **Không** đặt secret key hoặc `service_role` key trong bất kỳ tệp frontend nào.

## 4. Đăng nhập và dữ liệu

Đăng nhập bằng email/mật khẩu đã tạo ở bước 2, trên mọi thiết bị. Tiến độ và kết quả được tải từ database chung. Chọn đúng vai trò ở trang đăng nhập; vai trò thực tế được kiểm tra từ hồ sơ database.

Project Supabase và database chưa thể được tạo thay bạn từ workspace này. Sau khi cấu hình URL/key và chạy SQL, ứng dụng mới kết nối được với project của bạn.

Lưu ý: điểm bài kiểm tra hiện được tính trong JavaScript phía trình duyệt. Database lưu kết quả và giới hạn học sinh chỉ ghi dữ liệu của chính mình, nhưng điểm chưa được xác thực độc lập ở server. Không dùng kết quả này làm điểm chính thức nếu chưa chuyển phần chấm điểm sang server.
