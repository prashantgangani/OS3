import random
from math import gcd

# ---------------- PRIME CHECK ----------------
def is_prime(num: int) -> bool:
    if num < 2:
        return False
    for i in range(2, int(num ** 0.5) + 1):
        if num % i == 0:
            return False
    return True

# --------- RANDOM 10 DIGIT PRIME ------------
def generate_prime() -> int:
    while True:
        candidate = random.randint(10**9, 10**10 - 1)  # 10-digit
        if is_prime(candidate):
            return candidate

# ---------- MODULAR INVERSE -----------------
def mod_inverse(e: int, phi: int) -> int:
    # Extended Euclidean Algorithm
    def egcd(a: int, b: int):
        if a == 0:
            return b, 0, 1
        g, x1, y1 = egcd(b % a, a)
        x = y1 - (b // a) * x1
        y = x1
        return g, x, y

    g, x, _ = egcd(e, phi)
    if g != 1:
        return None
    return x % phi

# --------------- RSA START ------------------
print("\n--- RSA Algorithm Implementation ---\n")

# Generate p and q
p = generate_prime()
q = generate_prime()
while p == q:
    q = generate_prime()

print("p =", p)
print("q =", q)

n = p * q
phi_n = (p - 1) * (q - 1)

# Choose e
while True:
    e = random.randint(2, phi_n - 1)
    if gcd(e, phi_n) == 1:
        break

# Find d
d = mod_inverse(e, phi_n)

print("Public Key (e, n):", (e, n))
print("Private Key (d, n):", (d, n))

# -------- MESSAGE INPUT ----------
msg = input("\nEnter message : ")

# Convert message to ASCII blocks
msg_blocks = [ord(ch) for ch in msg]
print("\nMessage ASCII Blocks:", msg_blocks)

# -------- ENCRYPTION -------------
cipher = [pow(m, e, n) for m in msg_blocks]
print("\nEncrypted Message:", cipher)

# -------- DECRYPTION -------------
decrypted_chars = [chr(pow(c, d, n)) for c in cipher]
print("\nDecrypted Message:", "".join(decrypted_chars))