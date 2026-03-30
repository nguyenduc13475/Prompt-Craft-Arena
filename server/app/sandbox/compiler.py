from app.sandbox.builtins import SAFE_BUILTINS
from RestrictedPython import compile_restricted
from RestrictedPython.Eval import (
    default_guarded_getattr,
    default_guarded_getitem,
    default_guarded_getiter,
)


def compile_callback(code_str: str):
    """
    Biên dịch string code (do AI sinh ra) thành một hàm an toàn.
    Kỳ vọng code_str có dạng:
    def execute(event):
        # logic ở đây...
    """
    if not code_str or code_str.strip() == "":
        return None

    try:
        # Biên dịch trong môi trường hạn chế
        byte_code = compile_restricted(code_str, "<generated_ai_code>", "exec")

        # Thiết lập môi trường thực thi cục bộ (Sandboxed Local Environment)
        loc = {}
        glob = {
            "__builtins__": SAFE_BUILTINS,
            "_getiter_": default_guarded_getiter,
            "_getitem_": default_guarded_getitem,
            "_getattr_": default_guarded_getattr,
            # Cấp phép cho viết/thay đổi thuộc tính của object
            "_write_": lambda obj: obj,
        }

        # Thực thi bytecode để nạp hàm 'execute' vào dict `loc`
        exec(byte_code, glob, loc)

        # Trả về reference tới hàm đã compile
        if "execute" in loc:
            return loc["execute"]
        else:
            print("Lỗi: Code AI không chứa hàm 'execute(event)'.")
            return None

    except Exception as e:
        print(f"Lỗi biên dịch Sandbox: {e}")
        return None
