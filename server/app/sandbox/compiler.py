from app.sandbox.builtins import SAFE_BUILTINS
from RestrictedPython import compile_restricted, safe_builtins
from RestrictedPython.Eval import (
    default_guarded_getattr,
    default_guarded_getitem,
    default_guarded_getiter,
)


def compile_callback(code_str: str):
    """
    Biên dịch string code (do AI sinh ra) thành một hàm an toàn.
    """
    if not code_str or code_str.strip() == "":
        return None

    try:
        # Biên dịch trong môi trường hạn chế
        byte_code = compile_restricted(code_str, "<generated_ai_code>", "exec")

        loc = {}

        # 1. Kết hợp builtins an toàn của RestrictedPython (chứa __import__) với hàm custom của ta
        merged_builtins = safe_builtins.copy()
        merged_builtins.update(SAFE_BUILTINS)

        glob = {
            "__builtins__": merged_builtins,
            "_getiter_": default_guarded_getiter,
            "_getitem_": default_guarded_getitem,
            "_getattr_": default_guarded_getattr,
            "_write_": lambda obj: obj,
        }

        # 2. CỰC KỲ QUAN TRỌNG: Bơm trực tiếp module/hàm ('math', 'get_objects') vào global scope
        # để code AI hoặc MapFramework gọi thẳng mà không cần lệnh import
        for k, v in SAFE_BUILTINS.items():
            glob[k] = v

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
