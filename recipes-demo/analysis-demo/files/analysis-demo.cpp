// SPDX-License-Identifier: MIT
//
// analysis-demo - charge C++ en quatre phases distinctes, pour montrer ce
// que perf, un flame graph et une heatmap en font.
//
// Chaque phase vit dans sa propre fonction, non inlinee, pour apparaitre
// sous son nom dans les piles : multiplication de matrices, tri, table de
// hachage, expressions regulieres. Elles s'enchainent dans cet ordre, ce
// qui dessine quatre bandes successives sur une heatmap.
//
// Usage : analysis-demo [echelle]   (echelle entiere >= 1, defaut 1)

#include <algorithm>
#include <chrono>
#include <cstddef>
#include <cstdint>
#include <cstdio>
#include <cstdlib>
#include <random>
#include <regex>
#include <string>
#include <unordered_map>
#include <vector>

namespace {

using clock_type = std::chrono::steady_clock;

__attribute__((noinline)) double matmul(std::size_t n, std::size_t rounds)
{
    std::vector<double> a(n * n), b(n * n), c(n * n);
    for (std::size_t i = 0; i < n * n; ++i) {
        a[i] = static_cast<double>(i % 7) * 0.5;
        b[i] = static_cast<double>(i % 5 + 1) * 0.25;
    }
    double acc = 0.0;
    for (std::size_t r = 0; r < rounds; ++r) {
        for (std::size_t i = 0; i < n; ++i) {
            for (std::size_t j = 0; j < n; ++j) {
                double s = 0.0;
                for (std::size_t k = 0; k < n; ++k)
                    s += a[i * n + k] * b[k * n + j];
                c[i * n + j] = s;
            }
        }
        // Somme de toute la matrice : le calcul entier reste vivant.
        for (const double x : c)
            acc += x;
    }
    return acc;
}

__attribute__((noinline)) std::uint64_t sort_values(std::size_t count, std::size_t rounds)
{
    std::mt19937_64 rng(42);
    std::vector<std::uint64_t> v(count);
    std::uint64_t acc = 0;
    for (std::size_t r = 0; r < rounds; ++r) {
        for (auto &x : v)
            x = rng();
        std::sort(v.begin(), v.end());
        acc ^= v[count / 2];
    }
    return acc;
}

__attribute__((noinline)) std::size_t hash_table(std::size_t count, std::size_t rounds)
{
    std::size_t hits = 0;
    for (std::size_t r = 0; r < rounds; ++r) {
        std::unordered_map<std::string, std::size_t> m;
        for (std::size_t i = 0; i < count; ++i)
            m.emplace("key-" + std::to_string(i * 2654435761u % 1000003u), i);
        for (std::size_t i = 0; i < count; ++i)
            hits += m.count("key-" + std::to_string(i));
    }
    return hits;
}

__attribute__((noinline)) std::size_t parse_lines(std::size_t count, std::size_t rounds)
{
    const std::regex line_re(R"(^(\w+)=(\d+);(\w+)$)");
    std::vector<std::string> lines;
    lines.reserve(count);
    for (std::size_t i = 0; i < count; ++i)
        lines.push_back("field" + std::to_string(i % 97) + "=" + std::to_string(i) +
                        ";tag" + std::to_string(i % 13));
    std::size_t matched = 0;
    for (std::size_t r = 0; r < rounds; ++r) {
        for (const auto &l : lines) {
            std::smatch m;
            if (std::regex_match(l, m, line_re))
                matched += static_cast<std::size_t>(m[2].length());
        }
    }
    return matched;
}

template <typename F>
void run_phase(const char *name, F &&f)
{
    const auto t0 = clock_type::now();
    const auto result = f();
    const auto t1 = clock_type::now();
    const auto ms = std::chrono::duration_cast<std::chrono::milliseconds>(t1 - t0).count();
    std::printf("%-12s %8lld ms  (resultat %llu)\n", name, static_cast<long long>(ms),
                static_cast<unsigned long long>(result));
    std::fflush(stdout);
}

} // namespace

int main(int argc, char **argv)
{
    std::size_t scale = 1;
    if (argc > 1) {
        scale = static_cast<std::size_t>(std::strtoul(argv[1], nullptr, 10));
        if (scale == 0)
            scale = 1;
    }
    run_phase("matmul", [&] { return matmul(256, 20 * scale); });
    run_phase("sort", [&] { return sort_values(200000, 4 * scale); });
    run_phase("hash", [&] { return hash_table(50000, 3 * scale); });
    run_phase("regex", [&] { return parse_lines(20000, 3 * scale); });
    return 0;
}
