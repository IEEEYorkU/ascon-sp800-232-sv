import random

def randState():
    return random.getrandbits(320)

def split_ascon_state(state):
    return [(state >> (64 * i)) & ((1 << 64) - 1) for i in range(5)]

def rotr(x, n):
    return ((x >> n) | (x << (64 - n))) & ((1 << 64) - 1)

def main():
    state = randState()
    words = split_ascon_state(state)

    a = [19, 61, 1, 10, 7]
    b = [28, 39, 6, 17, 41]

    print("=== ASCON Diffusion Layer ===\n")
    print("Original state (320 bits):")

    after = []
    for i in range(5):
        Si = words[i]
        after_word = Si ^ rotr(Si, a[i]) ^ rotr(Si, b[i])
        after.append(after_word)

    print(f"{state:0320b}")

    print("each word start from s0:")
    print(f"{words[0]:064b}")
    print(f"{words[1]:064b}")
    print(f"{words[2]:064b}")
    print(f"{words[3]:064b}")
    print(f"{words[4]:064b}")

    print("\n=== After diffusion ===")
    print("".join(f"{x:064b}" for x in after[::-1]))
    print("each diffused word start from s0:")
    print(f"{after[0]:064b}")
    print(f"{after[1]:064b}")
    print(f"{after[2]:064b}")
    print(f"{after[3]:064b}")
    print(f"{after[4]:064b}")




if __name__ == "__main__":
    main()
