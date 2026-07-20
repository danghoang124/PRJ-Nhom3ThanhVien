using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using LucyAuthService.Data;
using LucyAuthService.DTOs;

namespace LucyAuthService.Controllers;

[ApiController]
[Route("api/users")]
[Authorize]
public class UserController : ControllerBase
{
    private readonly AppDbContext _context;

    public UserController(AppDbContext context)
    {
        _context = context;
    }

    [HttpGet]
    [Authorize(Roles = "admin")]
    [ProducesResponseType(typeof(List<UserResponse>), 200)]
    public async Task<IActionResult> GetAllUsers()
    {
        var users = await _context.Users
            .Select(u => new UserResponse
            {
                Id = u.Id,
                Email = u.Email,
                Role = u.Role,
                CreatedAt = u.CreatedAt
            })
            .ToListAsync();

        return Ok(users);
    }

    [HttpGet("me")]
    [ProducesResponseType(typeof(UserResponse), 200)]
    public IActionResult GetCurrentUser()
    {
        var userId = User.FindFirst(System.Security.Claims.ClaimTypes.NameIdentifier)?.Value;
        if (userId == null) return Unauthorized();

        return Ok(new UserResponse
        {
            Id = int.Parse(userId),
            Email = User.FindFirst(System.Security.Claims.ClaimTypes.Email)?.Value ?? "",
            Role = User.FindFirst(System.Security.Claims.ClaimTypes.Role)?.Value ?? "user"
        });
    }

    [HttpGet("verify")]
    [AllowAnonymous]
    [ProducesResponseType(typeof(object), 200)]
    public IActionResult VerifyToken()
    {
        if (User.Identity?.IsAuthenticated == true)
        {
            return Ok(new { valid = true, email = User.FindFirst(System.Security.Claims.ClaimTypes.Email)?.Value });
        }
        return Ok(new { valid = false });
    }
}
