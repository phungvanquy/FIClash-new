# Xray fixture results

Recorded on 2026-09-23, Linux arm64, Go 1.26.4, fork `b2facd1ef0c3c319f1d5c5c43eaa124b6b2fb85c`. All 179 subcases passed. A PASS for a negative case means the connection was rejected as required. These are local synthetic fixtures, not a reproduction of the user's unknown configuration.

| Server | REALITY | Other transports | Native Core |
| --- | ---: | ---: | ---: |
| 26.3.27 | 27 | 14 | 2 |
| 26.7.11 | 16 | 14 | 0 |
| 26.7.28 | 16 | 14 | 0 |
| 26.9.8 | 17 | 14 | 0 |
| 26.9.9 | 28 | 14 | 2 |
| 1.8.24 | 1 | 0 | 0 |

Other-transport counts include VLESS TLS/WS/gRPC, VMess TLS/WS, Trojan TLS/gRPC, six VLESS encryption mode/RTT combinations, and XUDP. Xray warns that gRPC is deprecated, but the pinned September binaries still accept it and pass the payload fixtures. The older server row only validates explicit legacy REALITY mode.

The native Core cases launch the built Linux executable through IPC, activate a staged profile, transfer REALITY payloads, reject an invalid replacement while preserving traffic, stop/restart listeners, and shut down. They do not claim Android, macOS, Windows Helper, GUI, or TUN device coverage.

## 26.3.27

| Fixture | Result |
| --- | --- |
| `TestXrayReality/default` | PASS |
| `TestXrayReality/minimum` | PASS |
| `TestXrayReality/xhttp` | PASS |
| `TestXrayReality/xhttp-minimum` | PASS |
| `TestXrayReality/maximum-accepted` | PASS |
| `TestXrayReality/minimum-rejected` | PASS |
| `TestXrayReality/maximum-rejected` | PASS |
| `TestXrayReality/wrong-key` | PASS |
| `TestXrayReality/wrong-short-id` | PASS |
| `TestXrayReality/wrong-sni` | PASS |
| `TestXrayReality/explicit-modern` | PASS |
| `TestXrayReality/old-fingerprint` | PASS |
| `TestXrayReality/fingerprint-default` | PASS |
| `TestXrayReality/fingerprint-firefox` | PASS |
| `TestXrayReality/fingerprint-safari` | PASS |
| `TestXrayReality/fingerprint-random` | PASS |
| `TestXrayReality/xhttp-packet-up` | PASS |
| `TestXrayReality/xhttp-stream-up` | PASS |
| `TestXrayReality/xhttp-stream-one` | PASS |
| `TestXrayReality/xhttp-ipv6` | PASS |
| `TestXrayReality/xhttp-independent-download` | PASS |
| `TestXrayReality/xhttp-invalid-download` | PASS |
| `TestXrayReality/mldsa-valid` | PASS |
| `TestXrayReality/mldsa-wrong` | PASS |
| `TestXrayReality/mldsa-absent` | PASS |
| `TestXrayReality/mldsa-omitted` | PASS |
| `TestXrayReality/mldsa-malformed` | PASS |
| `TestXrayNativeCore/tcp` | PASS |
| `TestXrayNativeCore/xhttp` | PASS |
| `TestXrayTransports/vless-tcp` | PASS |
| `TestXrayTransports/vless-ws` | PASS |
| `TestXrayTransports/vless-grpc` | PASS |
| `TestXrayTransports/vmess-tcp` | PASS |
| `TestXrayTransports/vmess-ws` | PASS |
| `TestXrayTransports/trojan-tcp` | PASS |
| `TestXrayTransports/trojan-grpc` | PASS |
| `TestXrayTransports/encryption-native-0rtt` | PASS |
| `TestXrayTransports/encryption-native-1rtt` | PASS |
| `TestXrayTransports/encryption-xorpub-0rtt` | PASS |
| `TestXrayTransports/encryption-xorpub-1rtt` | PASS |
| `TestXrayTransports/encryption-random-0rtt` | PASS |
| `TestXrayTransports/encryption-random-1rtt` | PASS |
| `TestXrayTransports/xudp` | PASS |

## 26.7.11

| Fixture | Result |
| --- | --- |
| `TestXrayReality/default` | PASS |
| `TestXrayReality/minimum` | PASS |
| `TestXrayReality/xhttp` | PASS |
| `TestXrayReality/xhttp-minimum` | PASS |
| `TestXrayReality/maximum-accepted` | PASS |
| `TestXrayReality/minimum-rejected` | PASS |
| `TestXrayReality/maximum-rejected` | PASS |
| `TestXrayReality/wrong-key` | PASS |
| `TestXrayReality/wrong-short-id` | PASS |
| `TestXrayReality/wrong-sni` | PASS |
| `TestXrayReality/explicit-modern` | PASS |
| `TestXrayReality/old-fingerprint` | PASS |
| `TestXrayReality/fingerprint-default` | PASS |
| `TestXrayReality/fingerprint-firefox` | PASS |
| `TestXrayReality/fingerprint-safari` | PASS |
| `TestXrayReality/fingerprint-random` | PASS |
| `TestXrayTransports/vless-tcp` | PASS |
| `TestXrayTransports/vless-ws` | PASS |
| `TestXrayTransports/vless-grpc` | PASS |
| `TestXrayTransports/vmess-tcp` | PASS |
| `TestXrayTransports/vmess-ws` | PASS |
| `TestXrayTransports/trojan-tcp` | PASS |
| `TestXrayTransports/trojan-grpc` | PASS |
| `TestXrayTransports/encryption-native-0rtt` | PASS |
| `TestXrayTransports/encryption-native-1rtt` | PASS |
| `TestXrayTransports/encryption-xorpub-0rtt` | PASS |
| `TestXrayTransports/encryption-xorpub-1rtt` | PASS |
| `TestXrayTransports/encryption-random-0rtt` | PASS |
| `TestXrayTransports/encryption-random-1rtt` | PASS |
| `TestXrayTransports/xudp` | PASS |

## 26.7.28

| Fixture | Result |
| --- | --- |
| `TestXrayReality/default` | PASS |
| `TestXrayReality/minimum` | PASS |
| `TestXrayReality/xhttp` | PASS |
| `TestXrayReality/xhttp-minimum` | PASS |
| `TestXrayReality/maximum-accepted` | PASS |
| `TestXrayReality/minimum-rejected` | PASS |
| `TestXrayReality/maximum-rejected` | PASS |
| `TestXrayReality/wrong-key` | PASS |
| `TestXrayReality/wrong-short-id` | PASS |
| `TestXrayReality/wrong-sni` | PASS |
| `TestXrayReality/explicit-modern` | PASS |
| `TestXrayReality/old-fingerprint` | PASS |
| `TestXrayReality/fingerprint-default` | PASS |
| `TestXrayReality/fingerprint-firefox` | PASS |
| `TestXrayReality/fingerprint-safari` | PASS |
| `TestXrayReality/fingerprint-random` | PASS |
| `TestXrayTransports/vless-tcp` | PASS |
| `TestXrayTransports/vless-ws` | PASS |
| `TestXrayTransports/vless-grpc` | PASS |
| `TestXrayTransports/vmess-tcp` | PASS |
| `TestXrayTransports/vmess-ws` | PASS |
| `TestXrayTransports/trojan-tcp` | PASS |
| `TestXrayTransports/trojan-grpc` | PASS |
| `TestXrayTransports/encryption-native-0rtt` | PASS |
| `TestXrayTransports/encryption-native-1rtt` | PASS |
| `TestXrayTransports/encryption-xorpub-0rtt` | PASS |
| `TestXrayTransports/encryption-xorpub-1rtt` | PASS |
| `TestXrayTransports/encryption-random-0rtt` | PASS |
| `TestXrayTransports/encryption-random-1rtt` | PASS |
| `TestXrayTransports/xudp` | PASS |

## 26.9.8

| Fixture | Result |
| --- | --- |
| `TestXrayReality/default` | PASS |
| `TestXrayReality/minimum` | PASS |
| `TestXrayReality/xhttp` | PASS |
| `TestXrayReality/xhttp-minimum` | PASS |
| `TestXrayReality/maximum-accepted` | PASS |
| `TestXrayReality/minimum-rejected` | PASS |
| `TestXrayReality/maximum-rejected` | PASS |
| `TestXrayReality/wrong-key` | PASS |
| `TestXrayReality/wrong-short-id` | PASS |
| `TestXrayReality/wrong-sni` | PASS |
| `TestXrayReality/explicit-modern` | PASS |
| `TestXrayReality/old-fingerprint` | PASS |
| `TestXrayReality/fingerprint-default` | PASS |
| `TestXrayReality/fingerprint-firefox` | PASS |
| `TestXrayReality/fingerprint-safari` | PASS |
| `TestXrayReality/fingerprint-random` | PASS |
| `TestXrayReality/legacy-rejected` | PASS |
| `TestXrayTransports/vless-tcp` | PASS |
| `TestXrayTransports/vless-ws` | PASS |
| `TestXrayTransports/vmess-tcp` | PASS |
| `TestXrayTransports/vmess-ws` | PASS |
| `TestXrayTransports/trojan-tcp` | PASS |
| `TestXrayTransports/encryption-native-0rtt` | PASS |
| `TestXrayTransports/encryption-native-1rtt` | PASS |
| `TestXrayTransports/encryption-xorpub-0rtt` | PASS |
| `TestXrayTransports/encryption-xorpub-1rtt` | PASS |
| `TestXrayTransports/encryption-random-0rtt` | PASS |
| `TestXrayTransports/encryption-random-1rtt` | PASS |
| `TestXrayTransports/xudp` | PASS |
| `TestXrayTransports/vless-grpc` | PASS |
| `TestXrayTransports/trojan-grpc` | PASS |

## 26.9.9

| Fixture | Result |
| --- | --- |
| `TestXrayReality/default` | PASS |
| `TestXrayReality/minimum` | PASS |
| `TestXrayReality/xhttp` | PASS |
| `TestXrayReality/xhttp-minimum` | PASS |
| `TestXrayReality/maximum-accepted` | PASS |
| `TestXrayReality/minimum-rejected` | PASS |
| `TestXrayReality/maximum-rejected` | PASS |
| `TestXrayReality/wrong-key` | PASS |
| `TestXrayReality/wrong-short-id` | PASS |
| `TestXrayReality/wrong-sni` | PASS |
| `TestXrayReality/explicit-modern` | PASS |
| `TestXrayReality/old-fingerprint` | PASS |
| `TestXrayReality/fingerprint-default` | PASS |
| `TestXrayReality/fingerprint-firefox` | PASS |
| `TestXrayReality/fingerprint-safari` | PASS |
| `TestXrayReality/fingerprint-random` | PASS |
| `TestXrayReality/xhttp-packet-up` | PASS |
| `TestXrayReality/xhttp-stream-up` | PASS |
| `TestXrayReality/xhttp-stream-one` | PASS |
| `TestXrayReality/xhttp-ipv6` | PASS |
| `TestXrayReality/xhttp-independent-download` | PASS |
| `TestXrayReality/xhttp-invalid-download` | PASS |
| `TestXrayReality/mldsa-valid` | PASS |
| `TestXrayReality/mldsa-wrong` | PASS |
| `TestXrayReality/mldsa-absent` | PASS |
| `TestXrayReality/mldsa-omitted` | PASS |
| `TestXrayReality/mldsa-malformed` | PASS |
| `TestXrayReality/legacy-rejected` | PASS |
| `TestXrayNativeCore/tcp` | PASS |
| `TestXrayNativeCore/xhttp` | PASS |
| `TestXrayTransports/vless-tcp` | PASS |
| `TestXrayTransports/vless-ws` | PASS |
| `TestXrayTransports/vmess-tcp` | PASS |
| `TestXrayTransports/vmess-ws` | PASS |
| `TestXrayTransports/trojan-tcp` | PASS |
| `TestXrayTransports/encryption-native-0rtt` | PASS |
| `TestXrayTransports/encryption-native-1rtt` | PASS |
| `TestXrayTransports/encryption-xorpub-0rtt` | PASS |
| `TestXrayTransports/encryption-xorpub-1rtt` | PASS |
| `TestXrayTransports/encryption-random-0rtt` | PASS |
| `TestXrayTransports/encryption-random-1rtt` | PASS |
| `TestXrayTransports/xudp` | PASS |
| `TestXrayTransports/vless-grpc` | PASS |
| `TestXrayTransports/trojan-grpc` | PASS |

## 1.8.24

| Fixture | Result |
| --- | --- |
| `TestXrayReality/legacy` | PASS |
