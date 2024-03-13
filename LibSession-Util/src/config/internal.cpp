#include "internal.hpp"

#include <oxenc/base32z.h>
#include <oxenc/base64.h>
#include <oxenc/hex.h>

#include <iterator>
#include <optional>

namespace session::config {

void check_session_id(std::string_view session_id) {
    if (!(session_id.size() == 66 && oxenc::is_hex(session_id) && session_id[0] == '0' &&
          session_id[1] == '5'))
        throw std::invalid_argument{
                "Invalid session ID: expected 66 hex digits starting with 05; got " +
                std::string{session_id}};
}

std::string session_id_to_bytes(std::string_view session_id) {
    check_session_id(session_id);
    return oxenc::from_hex(session_id);
}

void check_encoded_pubkey(std::string_view pk) {
    if (!((pk.size() == 64 && oxenc::is_hex(pk)) ||
          ((pk.size() == 43 || (pk.size() == 44 && pk.back() == '=')) && oxenc::is_base64(pk)) ||
          (pk.size() == 52 && oxenc::is_base32z(pk))))
        throw std::invalid_argument{"Invalid encoded pubkey: expected hex, base32z or base64"};
}

ustring decode_pubkey(std::string_view pk) {
    session::ustring pubkey;
    pubkey.reserve(32);
    if (pk.size() == 64 && oxenc::is_hex(pk))
        oxenc::from_hex(pk.begin(), pk.end(), std::back_inserter(pubkey));
    else if ((pk.size() == 43 || (pk.size() == 44 && pk.back() == '=')) && oxenc::is_base64(pk))
        oxenc::from_base64(pk.begin(), pk.end(), std::back_inserter(pubkey));
    else if (pk.size() == 52 && oxenc::is_base32z(pk))
        oxenc::from_base32z(pk.begin(), pk.end(), std::back_inserter(pubkey));
    else
        throw std::invalid_argument{"Invalid encoded pubkey: expected hex, base32z or base64"};
    return pubkey;
}

void make_lc(std::string& s) {
    for (auto& c : s)
        if (c >= 'A' && c <= 'Z')
            c += ('a' - 'A');
}

template <typename Scalar>
const Scalar* maybe_scalar(const session::config::dict& d, const char* key) {
    if (auto it = d.find(key); it != d.end())
        if (auto* sc = std::get_if<session::config::scalar>(&it->second))
            if (auto* i = std::get_if<Scalar>(sc))
                return i;
    return nullptr;
}

const session::config::set* maybe_set(const session::config::dict& d, const char* key) {
    if (auto it = d.find(key); it != d.end())
        if (auto* s = std::get_if<session::config::set>(&it->second))
            return s;
    return nullptr;
}

std::optional<int64_t> maybe_int(const session::config::dict& d, const char* key) {
    if (auto* i = maybe_scalar<int64_t>(d, key))
        return *i;
    return std::nullopt;
}

std::optional<std::string> maybe_string(const session::config::dict& d, const char* key) {
    if (auto* s = maybe_scalar<std::string>(d, key))
        return *s;
    return std::nullopt;
}

std::optional<std::string_view> maybe_sv(const session::config::dict& d, const char* key) {
    if (auto* s = maybe_scalar<std::string>(d, key))
        return *s;
    return std::nullopt;
}

std::optional<ustring> maybe_ustring(const session::config::dict& d, const char* key) {
    std::optional<ustring> result;
    if (auto* s = maybe_scalar<std::string>(d, key))
        result.emplace(reinterpret_cast<const unsigned char*>(s->data()), s->size());
    return result;
}

void set_flag(ConfigBase::DictFieldProxy&& field, bool val) {
    if (val)
        field = 1;
    else
        field.erase();
}

void set_positive_int(ConfigBase::DictFieldProxy&& field, int64_t val) {
    if (val > 0)
        field = val;
    else
        field.erase();
}

void set_nonzero_int(ConfigBase::DictFieldProxy&& field, int64_t val) {
    if (val != 0)
        field = val;
    else
        field.erase();
}

void set_nonempty_str(ConfigBase::DictFieldProxy&& field, std::string val) {
    if (!val.empty())
        field = std::move(val);
    else
        field.erase();
}

void set_nonempty_str(ConfigBase::DictFieldProxy&& field, std::string_view val) {
    if (!val.empty())
        field = val;
    else
        field.erase();
}

}  // namespace session::config
